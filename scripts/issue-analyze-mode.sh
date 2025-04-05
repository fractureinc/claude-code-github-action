#!/bin/bash
# Enable strict error checking
set -e

# Get input parameters
ISSUE_NUMBER=$1
REPO_OWNER=$2
REPO_NAME=$3
ANTHROPIC_API_KEY=$4
GITHUB_TOKEN=$5
DEBUG_MODE=${6:-"false"}
FEEDBACK=$7
REQUIRE_ORG_MEMBERSHIP=${8:-"true"}
ORGANIZATION=${9:-$REPO_OWNER}
PERSONAL_ACCESS_TOKEN=${10:-$GITHUB_TOKEN}
COMMENT_AUTHOR=${11:-""}

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
echo "Running issue-analyze-mode with parameters:"
echo "Issue Number: $ISSUE_NUMBER"
echo "Repo Owner: $REPO_OWNER"
echo "Repo Name: $REPO_NAME"

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
LOG_FILE="$OUTPUT_DIR/claude_issue_analyze_log_$ISSUE_NUMBER.txt"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "Starting issue-analyze mode at $(date)"

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
if ! ISSUE_DETAILS=$(gh issue view $ISSUE_NUMBER --repo "$FULL_REPO" --json title,body,labels,author); then
  echo "Error fetching issue details"
  exit 1
fi

# Extract issue data
ISSUE_TITLE=$(echo "$ISSUE_DETAILS" | jq -r '.title')
ISSUE_BODY=$(echo "$ISSUE_DETAILS" | jq -r '.body')
ISSUE_LABELS=$(echo "$ISSUE_DETAILS" | jq -r '.labels[].name' | tr '\n' ',' | sed 's/,$//' || echo "none")
ISSUE_AUTHOR=$(echo "$ISSUE_DETAILS" | jq -r '.author.login')

# Check if user is a member of the organization if required
if [[ "$REQUIRE_ORG_MEMBERSHIP" == "true" ]]; then
  # Use the comment author for the org membership check if provided, otherwise fall back to issue author
  CHECK_USER="${COMMENT_AUTHOR:-$ISSUE_AUTHOR}"
  echo "Checking if $CHECK_USER is a member of organization $ORGANIZATION"
  
  # Debug output
  echo "Comment Author: $COMMENT_AUTHOR"
  echo "Issue Author: $ISSUE_AUTHOR"
  echo "User being checked: $CHECK_USER"
  
  # Temporarily use the personal access token for org membership check if provided
  if [[ "$PERSONAL_ACCESS_TOKEN" != "$GITHUB_TOKEN" ]]; then
    echo "Using Personal Access Token for organization membership check"
    # Save current token auth
    TEMP_AUTH=$(gh auth status 2>&1 | grep "Logged in")
    # Switch to personal token for org check
    echo "$PERSONAL_ACCESS_TOKEN" | gh auth login --with-token
    ORG_CHECK=$(gh api -X GET /orgs/$ORGANIZATION/members/$CHECK_USER --silent -i || true)
    # Switch back to github token
    echo "$GITHUB_TOKEN" | gh auth login --with-token
  else
    echo "Using GitHub Token for organization membership check"
    ORG_CHECK=$(gh api -X GET /orgs/$ORGANIZATION/members/$CHECK_USER --silent -i || true)
  fi
  
  STATUS_CODE=$(echo "$ORG_CHECK" | head -n 1 | cut -d' ' -f2)
  
  if [[ "$STATUS_CODE" != "204" ]]; then
    echo "User $CHECK_USER is not a member of organization $ORGANIZATION. Skipping Claude analysis."
    
    # Leave a comment on the issue explaining why the analysis is skipped
    ISSUE_COMMENT=$(cat <<EOF
# Claude Code Analysis Skipped

Sorry, Claude Code can only analyze issues created by organization members.

This is to prevent API usage from users outside the organization.

---
🤖 Generated with Claude Code GitHub Action
EOF
)
    
    echo "Adding comment to issue #$ISSUE_NUMBER explaining why analysis was skipped"
    gh issue comment "$ISSUE_NUMBER" --repo "$FULL_REPO" --body "$ISSUE_COMMENT"
    
    echo "Exiting due to non-organization member request"
    exit 0
  else
    echo "User $CHECK_USER is a member of organization $ORGANIZATION. Proceeding with Claude analysis."
  fi
fi

# Create prompt for Claude
CLAUDE_PROMPT=$(cat <<EOF
You are Claude, an AI assistant tasked with analyzing issues in a GitHub repository.

Issue #$ISSUE_NUMBER: $ISSUE_TITLE

Issue Description:
$ISSUE_BODY
EOF
)

# Add additional instructions if provided
if [ -n "$FEEDBACK" ]; then
  CLAUDE_PROMPT+=$(cat <<EOF

Additional Instructions from User Comment:
$FEEDBACK
EOF
)
fi

# Complete the prompt
CLAUDE_PROMPT+=$(cat <<EOF

Your task is to:
1. Analyze the issue carefully to understand the problem
2. Identify likely causes of the issue
3. Suggest potential fixes without actually making any changes
4. Be specific about which files would need to be modified and how
5. If appropriate, provide code snippets showing potential solutions

Please be thorough in your analysis, but remember you are NOT making any changes to the code directly.
EOF
)

# Save the prompt for debugging
PROMPT_FILE="$OUTPUT_DIR/claude_prompt_analyze_$ISSUE_NUMBER.txt"
echo "$CLAUDE_PROMPT" > "$PROMPT_FILE"
echo "Prompt saved to $PROMPT_FILE for debugging"

# Run Claude to analyze the issue
CLAUDE_OUTPUT_FILE="$OUTPUT_DIR/claude_output_analyze_$ISSUE_NUMBER.txt"
echo "Running Claude to analyze the issue..."
if ! claude -p $CLAUDE_DEBUG_FLAG "$CLAUDE_PROMPT" > "$CLAUDE_OUTPUT_FILE" 2>"$OUTPUT_DIR/claude_error_analyze_$ISSUE_NUMBER.log"; then
  echo "Error: Claude execution failed"
  cat "$OUTPUT_DIR/claude_error_analyze_$ISSUE_NUMBER.log"
  exit 1
fi

# Get Claude's response
CLAUDE_RESPONSE=$(cat "$CLAUDE_OUTPUT_FILE")

# Add a comment to the issue with Claude's analysis
ISSUE_COMMENT=$(cat <<EOF
# Claude Code Analysis

$CLAUDE_RESPONSE

---
🤖 Generated with Claude Code GitHub Action
EOF
)

echo "Adding comment to issue #$ISSUE_NUMBER"
gh issue comment "$ISSUE_NUMBER" --repo "$FULL_REPO" --body "$ISSUE_COMMENT"

echo "Claude Code has analyzed issue #$ISSUE_NUMBER and added a comment with the analysis"
echo "Completed at $(date)"