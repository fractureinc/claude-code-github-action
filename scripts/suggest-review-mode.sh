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

# Set up authentication
echo "$GITHUB_TOKEN" | gh auth login --with-token
export ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY"

# Create a temp file for Claude's response
RESPONSE_FILE=$(mktemp)

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

# Build the prompt for Claude to generate a suggested change
PROMPT=$(cat <<EOF
This is a GitHub code review. Create a suggestion for the specific code at line $LINE_NUMBER in file '$FILE_PATH'.

Your response will be directly used by GitHub to create a suggestion on this line of code.
You MUST format your response as a SINGLE suggestion using the exact GitHub suggestion format:

\`\`\`suggestion
[Your improved code here]
\`\`\`

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

# Clean up
rm -f "$RESPONSE_FILE"

echo "Claude's in-line suggestion posted successfully!"