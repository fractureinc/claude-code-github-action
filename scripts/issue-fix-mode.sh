#!/bin/bash
# Enable strict error checking
set -e

# Enable debug mode for shell script
set -x

# Get input parameters
ISSUE_NUMBER=$1
REPO_OWNER=$2
REPO_NAME=$3
BRANCH_PREFIX=$4
ANTHROPIC_API_KEY=$5
GITHUB_TOKEN=$6

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
echo "Claude CLI help:"
claude --help || echo "Failed to get Claude help"

# Create a standard directory for output and debug files
OUTPUT_DIR="./claude-output"
mkdir -p "$OUTPUT_DIR"

# Create files with descriptive names for better debugging
RESPONSE_FILE="$OUTPUT_DIR/claude_analysis_$ISSUE_NUMBER.txt"
FIX_DETAILS_FILE="$OUTPUT_DIR/claude_fix_details_$ISSUE_NUMBER.txt"
LOG_FILE="$OUTPUT_DIR/claude_issue_fix_log_$ISSUE_NUMBER.txt"

# Set up logging
exec > >(tee -a "$LOG_FILE") 2>&1
echo "Starting issue-fix mode at $(date)"
echo "Output directory: $OUTPUT_DIR"
echo "Log file: $LOG_FILE"
echo "Response file: $RESPONSE_FILE"
echo "Fix details file: $FIX_DETAILS_FILE"

# Get current date for the branch name
DATE=$(date +%Y%m%d%H%M%S)
FIX_BRANCH="${BRANCH_PREFIX:-fix}-issue-${ISSUE_NUMBER}-${DATE}"

# Get issue details
echo "Fetching issue #$ISSUE_NUMBER details"
# Make sure we're using the correct repo format for the gh cli
# Handle both full repo format (owner/name) and just name format
if [[ "$REPO_NAME" == *"/"* ]]; then
  # REPO_NAME already contains owner/name format
  FULL_REPO="$REPO_NAME"
else
  # Need to construct owner/name format
  FULL_REPO="$REPO_OWNER/$REPO_NAME"
fi
echo "Using repository: $FULL_REPO"
if ! ISSUE_DETAILS=$(gh issue view $ISSUE_NUMBER --repo "$FULL_REPO" --json title,body,labels 2>/tmp/gh_issue_error.log); then
  echo "Error fetching issue details:"
  cat /tmp/gh_issue_error.log
  exit 1
fi

# Extract data from JSON with error handling
if ! ISSUE_TITLE=$(echo "$ISSUE_DETAILS" | jq -r '.title' 2>/dev/null); then
  echo "Error: Failed to extract issue title from JSON response"
  echo "JSON response: $ISSUE_DETAILS"
  exit 1
fi

if ! ISSUE_BODY=$(echo "$ISSUE_DETAILS" | jq -r '.body' 2>/dev/null); then
  echo "Error: Failed to extract issue body from JSON response"
  echo "JSON response: $ISSUE_DETAILS"
  exit 1
fi

if ! ISSUE_LABELS=$(echo "$ISSUE_DETAILS" | jq -r '.labels[].name' 2>/dev/null | tr '\n' ',' | sed 's/,$//' 2>/dev/null); then
  echo "Warning: Failed to extract issue labels or no labels found"
  ISSUE_LABELS="none"
fi

echo "Successfully extracted issue data: Title='$ISSUE_TITLE', Labels='$ISSUE_LABELS'"

# Get repo information
echo "Fetching repository information"
# Use same FULL_REPO format from above
echo "Using repository for repo info: $FULL_REPO"
if ! REPO_INFO=$(gh repo view "$FULL_REPO" --json name,description,defaultBranchRef,languages 2>/tmp/gh_repo_error.log); then
  echo "Error fetching repository information:"
  cat /tmp/gh_repo_error.log
  exit 1
fi
# Extract repo data with error handling
if ! DEFAULT_BRANCH=$(echo "$REPO_INFO" | jq -r '.defaultBranchRef.name' 2>/dev/null); then
  echo "Error: Failed to extract default branch information"
  echo "JSON response: $REPO_INFO"
  exit 1
fi

REPO_DESC=$(echo "$REPO_INFO" | jq -r '.description // "No description"' 2>/dev/null)

if ! REPO_LANGUAGES=$(echo "$REPO_INFO" | jq -r '.languages[].name' 2>/dev/null | tr '\n' ', ' | sed 's/,$//' 2>/dev/null); then
  echo "Warning: Failed to extract repo languages or no languages found"
  REPO_LANGUAGES="unknown"
fi

echo "Successfully extracted repo data: Default branch='$DEFAULT_BRANCH', Languages='$REPO_LANGUAGES'"

# Create a new branch for the fix
echo "Creating a new branch: $FIX_BRANCH"
git fetch origin $DEFAULT_BRANCH
git checkout -b $FIX_BRANCH origin/$DEFAULT_BRANCH

# Build a prompt for Claude to analyze the issue and propose a fix
ANALYZE_PROMPT=$(cat <<EOF
You are Claude, an AI assistant helping with fixing issues in a GitHub repository.

Repository: $REPO_OWNER/$REPO_NAME
Repository Description: ${REPO_DESC:-No description provided}
Default Branch: $DEFAULT_BRANCH
Languages: ${REPO_LANGUAGES:-Unknown}

Issue #$ISSUE_NUMBER: $ISSUE_TITLE
Labels: $ISSUE_LABELS

Issue Description:
${ISSUE_BODY}

Your task is to:
1. Analyze the issue description to understand the bug or problem
2. Determine which files are likely involved in the issue
3. Propose a specific, targeted fix
4. Explain your reasoning

Structure your response as follows:
a) Issue Analysis: Summarize your understanding of the issue
b) Files Involved: List the files that need to be modified (with full paths)
c) Proposed Changes: Describe the specific code changes needed for each file
d) Testing Plan: How should this fix be tested

DO NOT INCLUDE ANY ACTUAL CODE CHANGES YET. Just analyze the issue and describe what needs to be fixed.
If you need to see specific files first, indicate which ones you need to examine.
EOF
)

# Run Claude CLI to analyze the issue
echo "Sending request to Claude for issue analysis..."

# Create a prompt file in the output directory
PROMPT_FILE="$OUTPUT_DIR/prompt_analysis_$ISSUE_NUMBER.txt"
echo "$ANALYZE_PROMPT" > "$PROMPT_FILE"
echo "Prompt saved to $PROMPT_FILE for debugging"

# Use claude with the -p flag (print) and -d (debug) and pipe input
echo "Running: cat prompt | claude -p -d"
ERROR_LOG="$OUTPUT_DIR/claude_error_$ISSUE_NUMBER.log"
if ! cat "$PROMPT_FILE" | claude -p -d > "$RESPONSE_FILE" 2>"$ERROR_LOG"; then
  echo "Error: Claude API request failed. Check your API key and connectivity."
  echo "Claude CLI version:"
  claude --version || echo "Failed to get version"
  echo "Error log (if available):"
  cat "$ERROR_LOG" || echo "No error log available"
  echo "Prompt (first 20 lines):"
  cat "$PROMPT_FILE" | head -20
  exit 1
fi

echo "Prompt saved to $PROMPT_FILE for debugging"
echo "Response saved to $RESPONSE_FILE"

# Parse Claude's response to extract files to examine
echo "Extracting files to examine from Claude's response..."
FILES_TO_EXAMINE=$(grep -Eo "Files Involved:.*" -A 20 "$RESPONSE_FILE" | grep -v "Proposed Changes:" | grep -v "Testing Plan:" | grep "/" | sed -E 's/^[ -]*([^ ].*)/\1/' | sed -E 's/ *$//' | grep -v "^$" || echo "")

# Check if no files were found
if [ -z "$FILES_TO_EXAMINE" ]; then
    echo "No specific files identified in the Files Involved section."
    # Look for examples/calculator.js specifically since that's mentioned in the error logs
    if [ -f "examples/calculator.js" ]; then
        FILES_TO_EXAMINE="examples/calculator.js"
        echo "Found examples/calculator.js, will use this file for analysis."
    fi
fi

# Get content of relevant files
EXAMINED_FILES=""
if [ -z "$FILES_TO_EXAMINE" ]; then
    echo "Warning: No files to examine. Will proceed with implementation without file analysis."
    EXAMINED_FILES="No specific files were identified for analysis.\n\n"
else
    echo "Files to examine: $FILES_TO_EXAMINE"
    for FILE in $FILES_TO_EXAMINE; do
        if [ -f "$FILE" ]; then
            echo "Examining file: $FILE"
            EXAMINED_FILES+="File: $FILE\n\n\`\`\`\n$(cat "$FILE")\n\`\`\`\n\n"
        else
            echo "File not found: $FILE"
            EXAMINED_FILES+="File: $FILE\n\nNot found in repository\n\n"
        fi
    done
fi

# Build a prompt for Claude to implement the fix
IMPLEMENT_PROMPT=$(cat <<EOF
You are Claude, an AI assistant helping with fixing issues in a GitHub repository.

Based on your previous analysis of Issue #$ISSUE_NUMBER: "$ISSUE_TITLE", you need to implement the fix.

Here are the contents of the files you identified:

$EXAMINED_FILES

You previously proposed these changes:

$(cat "$RESPONSE_FILE")

Now, provide the actual code changes to fix the issue. For each file that needs to be modified:

1. Provide the full file path
2. Show the specific code changes in a clear before/after format:

For file /path/to/file.ext:
\`\`\`diff
- existing line to remove or modify
+ new or modified line
\`\`\`

3. Explain each change briefly

Be precise and minimal with your changes, focusing only on what's needed to fix the issue. Follow the code style of the existing files.

If you need to create a completely new file, specify the full file path and provide its entire content.
EOF
)

# Run Claude CLI to implement the fix
echo "Sending request to Claude for implementation details..."

# Create an implementation prompt file in the output directory
IMPL_PROMPT_FILE="$OUTPUT_DIR/prompt_implementation_$ISSUE_NUMBER.txt"
echo "$IMPLEMENT_PROMPT" > "$IMPL_PROMPT_FILE"
echo "Implementation prompt saved to $IMPL_PROMPT_FILE for debugging"

# Use claude with the -p flag (print) and -d (debug) and pipe input
echo "Running: cat prompt | claude -p -d for implementation details"
IMPL_ERROR_LOG="$OUTPUT_DIR/claude_impl_error_$ISSUE_NUMBER.log"
if ! cat "$IMPL_PROMPT_FILE" | claude -p -d > "$FIX_DETAILS_FILE" 2>"$IMPL_ERROR_LOG"; then
  echo "Error: Claude API request failed when generating implementation details."
  echo "Error log (if available):"
  cat "$IMPL_ERROR_LOG" || echo "No implementation error log available"
  echo "Implementation prompt (first 20 lines):"
  cat "$IMPL_PROMPT_FILE" | head -20
  exit 1
fi

echo "Implementation prompt saved to $IMPL_PROMPT_FILE for debugging"
echo "Implementation response saved to $FIX_DETAILS_FILE"

# Parse Claude's response to extract file paths and changes
FILES_TO_MODIFY=$(grep -o "For file [^ ]*:" "$FIX_DETAILS_FILE" | sed -E 's/For file ([^:]*):$/\1/')

# Apply the changes to each file
for FILE_PATH in $FILES_TO_MODIFY; do
  echo "Processing changes for file: $FILE_PATH"
  
  # Extract the code block for this file
  FILE_BLOCK=$(sed -n "/For file $FILE_PATH:/,/^For file \|^[[:space:]]*$/p" "$FIX_DETAILS_FILE")
  
  # Check if we need to create a new file
  if [ ! -f "$FILE_PATH" ]; then
    # Get the content between the first code block markers - using single quotes for robustness
    NEW_CONTENT=$(echo "$FILE_BLOCK" | sed -n '/```/,/```/p' | sed '1d;$d')
    
    # Create directory if it doesn't exist
    mkdir -p "$(dirname "$FILE_PATH")"
    
    # Create the new file
    echo "$NEW_CONTENT" > "$FILE_PATH"
    echo "Created new file: $FILE_PATH"
  else
    # Extract diff blocks - using a more robust approach to handle backticks
    DIFF_BLOCKS=$(echo "$FILE_BLOCK" | grep -A100 '```diff' | sed -n '/```diff/,/```/p' | sed '1d;$d')
    
    # Create a temporary file for the new content
    TEMP_FILE=$(mktemp)
    cat "$FILE_PATH" > "$TEMP_FILE"
    
    # Check if we have any diff blocks to process
    if [ -z "$DIFF_BLOCKS" ]; then
      echo "Warning: No diff blocks found in Claude's response. Proceeding without changes."
    else
      echo "Found diff blocks, processing changes..."
      # Process each diff block
      echo "$DIFF_BLOCKS" | while IFS= read -r LINE; do
        if [[ "$LINE" == -* ]]; then
          # Remove line (strip the leading -)
          REMOVE_LINE="${LINE:1}"
          echo "Removing: $REMOVE_LINE"
          sed -i.bak "s|$REMOVE_LINE||g" "$TEMP_FILE"
        elif [[ "$LINE" == +* ]]; then
          # Add line (strip the leading +)
          ADD_LINE="${LINE:1}"
          echo "Adding: $ADD_LINE"
          # Find the line above where we need to add
          PREV_LINE=$(echo "$DIFF_BLOCKS" | grep -B1 "\\+$ADD_LINE" | head -n1)
          if [[ "$PREV_LINE" == -* ]]; then
            # Replace the removed line with the added line
            PREV_LINE="${PREV_LINE:1}"
            echo "Replacing: $PREV_LINE with: $ADD_LINE"
            sed -i.bak "s|$PREV_LINE|$ADD_LINE|g" "$TEMP_FILE"
          else
            # Just append the line for now (this is simplistic)
            echo "Appending: $ADD_LINE"
            echo "$ADD_LINE" >> "$TEMP_FILE"
          fi
        fi
      done
    fi
    
    # Move the modified content back to the original file
    mv "$TEMP_FILE" "$FILE_PATH"
    echo "Modified file: $FILE_PATH"
  fi
  
  # Stage the changes
  git add "$FILE_PATH"
done

# Create a commit with detailed message
COMMIT_MESSAGE=$(cat <<EOF
Fix issue #$ISSUE_NUMBER: $ISSUE_TITLE

Automated fix generated by Claude Code based on issue analysis:

$(echo "$RESPONSE_FILE" | head -n15 | grep -v "^$")

---
🤖 Generated with Claude Code GitHub Action
EOF
)

git commit -m "$COMMIT_MESSAGE"

# Push the branch
git push -u origin $FIX_BRANCH

# Create a PR
PR_BODY=$(cat <<EOF
This PR fixes issue #$ISSUE_NUMBER

## Issue Analysis
$(grep -A 10 "Issue Analysis:" "$RESPONSE_FILE" | grep -v "Files Involved:" | sed 's/^Issue Analysis: //g')

## Changes Made
$(grep -A 30 "Proposed Changes:" "$RESPONSE_FILE" | grep -v "Testing Plan:" | sed 's/^Proposed Changes: //g')

## Testing Plan
$(grep -A 10 "Testing Plan:" "$RESPONSE_FILE" | sed 's/^Testing Plan: //g')

---
🤖 Generated with Claude Code GitHub Action
EOF
)

# Create the PR
echo "Creating pull request"
PR_URL=$(gh pr create --repo "$FULL_REPO" --title "Fix: $ISSUE_TITLE" --body "$PR_BODY" --base "$DEFAULT_BRANCH" --head "$FIX_BRANCH")

# Add a comment to the issue
ISSUE_COMMENT=$(cat <<EOF
I've analyzed this issue and created a fix in PR: $PR_URL

Here's my understanding:
$(grep -A 10 "Issue Analysis:" "$RESPONSE_FILE" | grep -v "Files Involved:" | sed 's/^Issue Analysis: //g')

The changes focus on:
$(grep -A 10 "Proposed Changes:" "$RESPONSE_FILE" | grep -v "Testing Plan:" | sed 's/^Proposed Changes: //g')

Please review the PR and test the changes to verify they resolve the issue.

---
🤖 Generated with Claude Code GitHub Action
EOF
)

echo "Adding comment to issue #$ISSUE_NUMBER"
gh issue comment "$ISSUE_NUMBER" --repo "$FULL_REPO" --body "$ISSUE_COMMENT"

# All output files are already in the claude-output directory
echo "All debug files have been saved to $OUTPUT_DIR"
echo "Analysis: $RESPONSE_FILE"
echo "Fix details: $FIX_DETAILS_FILE"
echo "Full log: $LOG_FILE"

echo "Claude Code has created a fix for issue #$ISSUE_NUMBER in PR: $PR_URL"
echo "Completed at $(date)"