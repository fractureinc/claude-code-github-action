#!/bin/bash
# Enable strict error checking
set -e

# Get input parameters
ISSUE_NUMBER=$1
REPO_OWNER=$2
REPO_NAME=$3
BRANCH_PREFIX=$4
ANTHROPIC_API_KEY=$5
GITHUB_TOKEN=$6
ISSUE_LABEL=${7:-"claude-fix"}
DEBUG_MODE=${8:-"false"}

# Enable debug mode if requested
if [[ "$DEBUG_MODE" == "true" ]]; then
  set -x
  CLAUDE_DEBUG_FLAG="-d"
  echo "Debug mode enabled"
else
  CLAUDE_DEBUG_FLAG=""
fi

# Validate required inputs
if [ -z "$ISSUE_NUMBER" ]; then
  echo "Error: Missing issue number"
  exit 1
fi

if [ -z "$REPO_OWNER" ]; then
  echo "Error: Missing repository owner"
  exit 1
fi

if [ -z "$REPO_NAME" ]; then
  echo "Error: Missing repository name"
  exit 1
fi

if [ -z "$ANTHROPIC_API_KEY" ]; then
  echo "Error: Missing Anthropic API key"
  exit 1
fi

if [ -z "$GITHUB_TOKEN" ]; then
  echo "Error: Missing GitHub token"
  exit 1
fi

# Check for required tools
if ! command -v jq &> /dev/null; then
  echo "Error: jq is required but not installed"
  exit 1
fi

if ! command -v gh &> /dev/null; then
  echo "Error: GitHub CLI (gh) is required but not installed"
  exit 1
fi

# Log parameter values for debugging (excluding sensitive info)
echo "Running issue-fix-mode with parameters:"
echo "Issue Number: $ISSUE_NUMBER"
echo "Repo Owner: $REPO_OWNER"
echo "Repo Name: $REPO_NAME"
echo "Branch Prefix: ${BRANCH_PREFIX:-fix}"

# Set up authentication
echo "$GITHUB_TOKEN" | gh auth login --with-token
export ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY"

# Check Claude CLI availability and version
echo "Checking Claude CLI installation..."
which claude || echo "Claude CLI not found in PATH"
claude --version || echo "Failed to get Claude version"

# Create output directory
OUTPUT_DIR="./claude-output"
mkdir -p "$OUTPUT_DIR"

# Set up logging
LOG_FILE="$OUTPUT_DIR/claude_issue_fix_log_$ISSUE_NUMBER.txt"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "Starting issue-fix mode at $(date)"

# Get current date for the branch name
DATE=$(date +%Y%m%d%H%M%S)
FIX_BRANCH="${BRANCH_PREFIX:-fix}-issue-${ISSUE_NUMBER}-${DATE}"

# Get issue details
echo "Fetching issue #$ISSUE_NUMBER details"
# Handle both full repo format (owner/name) and just name format
if [[ "$REPO_NAME" == *"/"* ]]; then
  # REPO_NAME already contains owner/name format
  FULL_REPO="$REPO_NAME"
else
  # Need to construct owner/name format
  FULL_REPO="$REPO_OWNER/$REPO_NAME"
fi
echo "Using repository: $FULL_REPO"
if ! ISSUE_DETAILS=$(gh issue view $ISSUE_NUMBER --repo "$FULL_REPO" --json title,body,labels); then
  echo "Error fetching issue details"
  exit 1
fi

# Extract issue data
ISSUE_TITLE=$(echo "$ISSUE_DETAILS" | jq -r '.title')
ISSUE_BODY=$(echo "$ISSUE_DETAILS" | jq -r '.body')
ISSUE_LABELS=$(echo "$ISSUE_DETAILS" | jq -r '.labels[].name' | tr '\n' ',' | sed 's/,$//' || echo "none")

# Get repo info for default branch
REPO_INFO=$(gh repo view "$FULL_REPO" --json name,description,defaultBranchRef)
DEFAULT_BRANCH=$(echo "$REPO_INFO" | jq -r '.defaultBranchRef.name')

# Create a new branch for the fix
echo "Creating a new branch: $FIX_BRANCH"
git fetch origin $DEFAULT_BRANCH
git checkout -b $FIX_BRANCH origin/$DEFAULT_BRANCH

# Create prompt for Claude
CLAUDE_PROMPT=$(cat <<EOF
You are Claude, an AI assistant tasked with fixing issues in a GitHub repository.

Issue #$ISSUE_NUMBER: $ISSUE_TITLE

Issue Description:
$ISSUE_BODY

Your task is to:
1. Analyze the issue carefully to understand the problem
2. Look through the repository to identify the relevant files that need to be modified
3. Make precise changes to fix the issue
4. Use the Edit tool to modify files directly when needed
5. Be minimal in your changes - only modify what's necessary to fix the issue

After making changes, provide a summary of what you did in this format:

---SUMMARY---
[Your detailed summary of changes, including which files were modified and how]
---END SUMMARY---

Remember:
- Be specific in your changes
- Only modify files that are necessary to fix the issue
- Follow existing code style and conventions
- Make the minimal changes needed to resolve the issue
EOF
)

# Save the prompt for debugging
PROMPT_FILE="$OUTPUT_DIR/claude_prompt_$ISSUE_NUMBER.txt"
echo "$CLAUDE_PROMPT" > "$PROMPT_FILE"
echo "Prompt saved to $PROMPT_FILE for debugging"

# Run Claude with specific allowed tools
CLAUDE_OUTPUT_FILE="$OUTPUT_DIR/claude_output_$ISSUE_NUMBER.txt"
echo "Running Claude to fix the issue..."
if ! claude -p $CLAUDE_DEBUG_FLAG "$CLAUDE_PROMPT" --allowedTools "Bash(git diff:*)" "Bash(git log:*)" Edit > "$CLAUDE_OUTPUT_FILE" 2>"$OUTPUT_DIR/claude_error_$ISSUE_NUMBER.log"; then
  echo "Error: Claude execution failed"
  cat "$OUTPUT_DIR/claude_error_$ISSUE_NUMBER.log"
  exit 1
fi

# Check if any changes were made
if [[ -z $(git status --porcelain) ]]; then
  echo "No changes were made by Claude"
  exit 1
fi

# Extract Claude's summary
if grep -q -- "---SUMMARY---" "$CLAUDE_OUTPUT_FILE"; then
  SUMMARY=$(sed -n '/---SUMMARY---/,/---END SUMMARY---/p' "$CLAUDE_OUTPUT_FILE" | grep -v -- "---SUMMARY---" | grep -v -- "---END SUMMARY---")
else
  SUMMARY="Changes were made by Claude Code based on the issue description. Check the PR for details of the changes."
fi

# Create a commit with detailed message
COMMIT_MESSAGE=$(cat <<EOF
Fix issue #$ISSUE_NUMBER: $ISSUE_TITLE

Automated fix generated by Claude Code based on issue analysis.

---
🤖 Generated with Claude Code GitHub Action
EOF
)

# Commit the changes
echo "Committing changes..."
git add .
git commit -m "$COMMIT_MESSAGE"

# Push the branch
echo "Pushing branch to remote..."
git push -u origin $FIX_BRANCH

# Create PR body
PR_BODY=$(cat <<EOF
This PR fixes issue #$ISSUE_NUMBER

## Changes Summary

$SUMMARY

## Original Issue

$ISSUE_BODY

---
🤖 Generated with Claude Code GitHub Action
EOF
)

# Create the PR
echo "Creating pull request..."
PR_URL=$(gh pr create --repo "$FULL_REPO" --title "Fix: $ISSUE_TITLE" --body "$PR_BODY" --base "$DEFAULT_BRANCH" --head "$FIX_BRANCH")

# Add a comment to the issue
ISSUE_COMMENT=$(cat <<EOF
I've analyzed this issue and created a fix in PR: $PR_URL

Here's a summary of the changes:

$SUMMARY

Please review the PR and test the changes to verify they resolve the issue.

---
🤖 Generated with Claude Code GitHub Action
EOF
)

echo "Adding comment to issue #$ISSUE_NUMBER"
gh issue comment "$ISSUE_NUMBER" --repo "$FULL_REPO" --body "$ISSUE_COMMENT"

echo "All debug files have been saved to $OUTPUT_DIR"
echo "Claude Code has created a fix for issue #$ISSUE_NUMBER in PR: $PR_URL"
echo "Completed at $(date)"