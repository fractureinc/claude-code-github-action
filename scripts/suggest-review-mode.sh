#!/bin/bash
set -e

# Get input parameters
PR_NUMBER=$1
FEEDBACK=$2
FILE_PATH=$3
LINE_NUMBER=$4
COMMENT_ID=$5
ANTHROPIC_API_KEY=$6
GITHUB_TOKEN=$7
STRICT_MODE=$8

# Default to strict mode if not provided
if [ -z "$STRICT_MODE" ]; then
    STRICT_MODE="true"
fi

# Set up authentication
echo "$GITHUB_TOKEN" | gh auth login --with-token
export ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY"

# Create a temp files for Claude's responses
RESPONSE_FILE=$(mktemp)
ADDITIONAL_SUGGESTIONS_FILE=$(mktemp)

# Get PR details using GitHub CLI
echo "Fetching PR details for PR #$PR_NUMBER"
PR_DETAILS=$(gh pr view $PR_NUMBER --json title,body,baseRefName,headRefName,additions,deletions,changedFiles,state)

PR_TITLE=$(echo "$PR_DETAILS" | jq -r '.title')
PR_BODY=$(echo "$PR_DETAILS" | jq -r '.body')
PR_BASE=$(echo "$PR_DETAILS" | jq -r '.baseRefName')
PR_HEAD=$(echo "$PR_DETAILS" | jq -r '.headRefName')
PR_STATE=$(echo "$PR_DETAILS" | jq -r '.state')

# Checkout PR branch for full repo context
echo "Checking out PR branch: $PR_HEAD"
git fetch origin pull/$PR_NUMBER/head:$PR_HEAD
git checkout $PR_HEAD

# Get the specific file content
FILE_CONTENT=$(cat "$FILE_PATH")

# Get a context window around the line in question (10 lines before and after)
LINE_START=$((LINE_NUMBER - 10))
if [ $LINE_START -lt 1 ]; then
    LINE_START=1
fi
LINE_END=$((LINE_NUMBER + 10))
CONTEXT_CONTENT=$(sed -n "${LINE_START},${LINE_END}p" "$FILE_PATH")

# Get repo information
REPO_INFO=$(gh repo view --json name,description,defaultBranchRef,languages)
REPO_NAME=$(echo "$REPO_INFO" | jq -r '.name')
REPO_DESC=$(echo "$REPO_INFO" | jq -r '.description')
REPO_DEFAULT_BRANCH=$(echo "$REPO_INFO" | jq -r '.defaultBranchRef.name')
REPO_LANGUAGES=$(echo "$REPO_INFO" | jq -r '.languages[].name' | tr '\n' ', ' | sed 's/,$//')

# Add strict mode instructions if enabled
STRICT_INSTRUCTIONS=""
if [ "$STRICT_MODE" = "true" ]; then
    STRICT_INSTRUCTIONS=$(cat <<EOF

IMPORTANT - STRICT MODE IS ENABLED:
1. You MUST address ONLY what the user explicitly asked for in their query
2. Do NOT make any unrelated improvements to the code, even if they would be beneficial
3. If the user asks to "add X", focus exclusively on adding X, not refactoring existing code
4. If you identify other issues in the code, DO NOT address them in your suggestion
5. Stay hyper-focused on the specific request, even if other improvements seem obvious
EOF
)
fi

# Build the prompt for Claude to generate a suggested change
PROMPT=$(cat <<EOF
This is a GitHub code review. Create a suggestion for the specific code at line $LINE_NUMBER in file '$FILE_PATH'.

Your response will be directly used by GitHub to create a suggestion on this line of code.
You MUST format your response as a SINGLE suggestion using the exact GitHub suggestion format:

\`\`\`suggestion
[Your improved code here]
\`\`\`
$STRICT_INSTRUCTIONS

Guidelines:
1. Focus ONLY on line $LINE_NUMBER and immediately surrounding lines
2. Keep the suggestion concise - it should replace just what needs to be changed
3. Maintain the existing indentation and code style
4. Ensure your suggestion is syntactically correct
5. Start your response with a brief explanation, then provide the suggestion block
6. Your suggestion will be applied directly to the code via GitHub's suggestion feature

Repository: $REPO_NAME 
PR: $PR_TITLE
File being reviewed: $FILE_PATH
Line number: $LINE_NUMBER

Context (code around line $LINE_NUMBER):
\`\`\`
$CONTEXT_CONTENT
\`\`\`

Complete file content:
\`\`\`
$FILE_CONTENT
\`\`\`

User query:
$FEEDBACK

Provide a single, specific suggestion that addresses this query for the code at line $LINE_NUMBER.
EOF
)

# Run Claude CLI
echo "Sending request to Claude for in-line suggestion..."
echo "$PROMPT" | claude -p - > "$RESPONSE_FILE"

# Reply to the specific comment with Claude's suggestion
echo "Posting Claude's suggested change as a reply to the comment"
gh api --method POST "/repos/:owner/:repo/pulls/$PR_NUMBER/comments/$COMMENT_ID/replies" \
   -F body="@$RESPONSE_FILE"

# If in non-strict mode, check for additional improvement suggestions
if [ "$STRICT_MODE" = "false" ]; then
    ADDITIONAL_PROMPT=$(cat <<EOF
You've already provided a suggestion that directly addresses the user's query for line $LINE_NUMBER in file '$FILE_PATH'.

Now, identify any additional code improvements that would be beneficial beyond what was specifically requested. 
These should be improvements that weren't part of the original request but would enhance code quality, 
readability, performance, or maintainability.

Format your response as:
1. A brief explanation of why these additional improvements would be valuable
2. Clearly labeled additional suggestions (not using the GitHub suggestion format)

File being reviewed: $FILE_PATH
Line number context: $LINE_NUMBER

Context (code around line $LINE_NUMBER):
\`\`\`
$CONTEXT_CONTENT
\`\`\`

Complete file content:
\`\`\`
$FILE_CONTENT
\`\`\`

If you don't have any additional suggestions beyond what was directly requested, respond with "No additional improvements suggested."
EOF
)

    echo "Checking for additional improvement suggestions..."
    echo "$ADDITIONAL_PROMPT" | claude -p - > "$ADDITIONAL_SUGGESTIONS_FILE"
    
    # Only post additional suggestions if they exist
    if ! grep -q "No additional improvements suggested" "$ADDITIONAL_SUGGESTIONS_FILE"; then
        echo "Posting additional improvement suggestions..."
        ADDITIONAL_CONTENT="## Additional Suggestions\n\nWhile addressing your specific request, I noticed some other potential improvements:\n\n$(cat "$ADDITIONAL_SUGGESTIONS_FILE")\n\n*These are optional suggestions beyond what you specifically requested.*"
        gh api --method POST "/repos/:owner/:repo/pulls/$PR_NUMBER/comments/$COMMENT_ID/replies" \
           -F body="$ADDITIONAL_CONTENT"
    fi
fi

# Clean up
rm -f "$RESPONSE_FILE" "$ADDITIONAL_SUGGESTIONS_FILE"

echo "Claude's suggestions posted successfully!"