#!/bin/bash
set -e

# Get input parameters
PR_NUMBER=$1
FEEDBACK=$2
ANTHROPIC_API_KEY=$3
GITHUB_TOKEN=$4

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
PR_ADDITIONS=$(echo "$PR_DETAILS" | jq -r '.additions')
PR_DELETIONS=$(echo "$PR_DETAILS" | jq -r '.deletions')
PR_CHANGED_FILES=$(echo "$PR_DETAILS" | jq -r '.changedFiles')

# Checkout PR branch for full repo context
echo "Checking out PR branch: $PR_HEAD"
git fetch origin pull/$PR_NUMBER/head:$PR_HEAD
git checkout $PR_HEAD

# Get list of files changed
echo "Fetching files changed in the PR"
PR_FILES=$(gh pr view $PR_NUMBER --json files)

# Get file content diffs
echo "Fetching file content diffs"
PR_DIFF=$(gh pr diff $PR_NUMBER)

# Get summary of files changed for the PR metadata
FILES_LIST=$(echo "$PR_FILES" | jq -r '.files[] | "- " + .path + " (" + .status + ", +" + (.additions | tostring) + "/-" + (.deletions | tostring) + ")"')

# Get repo information
REPO_INFO=$(gh repo view --json name,description,defaultBranchRef,languages)
REPO_NAME=$(echo "$REPO_INFO" | jq -r '.name')
REPO_DESC=$(echo "$REPO_INFO" | jq -r '.description')
REPO_DEFAULT_BRANCH=$(echo "$REPO_INFO" | jq -r '.defaultBranchRef.name')
REPO_LANGUAGES=$(echo "$REPO_INFO" | jq -r '.languages[].name' | tr '\n' ', ' | sed 's/,$//')

# Build the prompt with rich context and instructions to create GitHub suggestions
PROMPT=$(cat <<EOF
This is a GitHub PR review. Format suggested code changes using GitHub's clickable suggestions syntax:

\`\`\`suggestion
[code here]
\`\`\`

Each suggestion must follow this exact format to be clickable by the PR author.

Repository: $REPO_NAME
Repository Description: ${REPO_DESC:-No description provided}
Default Branch: $REPO_DEFAULT_BRANCH
Languages: ${REPO_LANGUAGES:-Unknown}

Pull Request #$PR_NUMBER: $PR_TITLE
PR Description:
${PR_BODY:-No description provided}

PR Status: $PR_STATE
Branch: $PR_HEAD → $PR_BASE
Changes: +$PR_ADDITIONS/-$PR_DELETIONS in $PR_CHANGED_FILES files

Files changed in this PR:
$FILES_LIST

Diff of changes:
\`\`\`diff
$PR_DIFF
\`\`\`

User query:
$FEEDBACK

IMPORTANT INSTRUCTIONS:

1. When suggesting code changes, format them as GitHub suggested changes using the syntax shown above
2. For each suggestion, explain your reasoning before the code block
3. Only suggest changes that directly relate to the user's query
4. Ensure your suggestions are complete, syntactically correct, and maintain the existing code style

Example of good suggestion format:

I suggest improving the error handling in this function:

\`\`\`suggestion
try {
    const result = await api.getData();
    return result;
} catch (error) {
    console.error('Failed to fetch data:', error);
    return null;
}
\`\`\`

Provide helpful, clear and concise suggestions that can be directly applied by the PR author.
EOF
)

# Run Claude CLI
echo "Sending request to Claude for suggested changes..."
echo "$PROMPT" | claude -p - > "$RESPONSE_FILE"

# Post response as PR comment
echo "Posting Claude's suggested changes as PR comment"
gh pr comment $PR_NUMBER --body-file "$RESPONSE_FILE"

# Clean up
rm -f "$RESPONSE_FILE"

echo "Claude's suggested changes posted successfully!"