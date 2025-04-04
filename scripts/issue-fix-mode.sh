#!/bin/bash
set -e

# Get input parameters
ISSUE_NUMBER=$1
REPO_OWNER=$2
REPO_NAME=$3
BRANCH_PREFIX=$4
ANTHROPIC_API_KEY=$5
GITHUB_TOKEN=$6

# Set up authentication
echo "$GITHUB_TOKEN" | gh auth login --with-token
export ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY"

# Create temp files for Claude's responses
RESPONSE_FILE=$(mktemp)
FIX_DETAILS_FILE=$(mktemp)

# Get current date for the branch name
DATE=$(date +%Y%m%d%H%M%S)
FIX_BRANCH="${BRANCH_PREFIX:-fix}-issue-${ISSUE_NUMBER}-${DATE}"

# Get issue details
echo "Fetching issue #$ISSUE_NUMBER details"
ISSUE_DETAILS=$(gh issue view $ISSUE_NUMBER --json title,body,labels)

ISSUE_TITLE=$(echo "$ISSUE_DETAILS" | jq -r '.title')
ISSUE_BODY=$(echo "$ISSUE_DETAILS" | jq -r '.body')
ISSUE_LABELS=$(echo "$ISSUE_DETAILS" | jq -r '.labels[].name' | tr '\n' ',' | sed 's/,$//')

# Get repo information
REPO_INFO=$(gh repo view --json name,description,defaultBranchRef,languages)
REPO_DESC=$(echo "$REPO_INFO" | jq -r '.description')
DEFAULT_BRANCH=$(echo "$REPO_INFO" | jq -r '.defaultBranchRef.name')
REPO_LANGUAGES=$(echo "$REPO_INFO" | jq -r '.languages[].name' | tr '\n' ', ' | sed 's/,$//')

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
echo "$ANALYZE_PROMPT" | claude -p - > "$RESPONSE_FILE"

# Parse Claude's response to extract files to examine
FILES_TO_EXAMINE=$(grep -Eo "Files Involved:.*" -A 20 "$RESPONSE_FILE" | grep -v "Proposed Changes:" | grep -v "Testing Plan:" | grep "/" | sed -E 's/^[ -]*([^ ].*)/\1/' | sed -E 's/ *$//' | grep -v "^$")

# Get content of relevant files
EXAMINED_FILES=""
for FILE in $FILES_TO_EXAMINE; do
  if [ -f "$FILE" ]; then
    echo "Examining file: $FILE"
    EXAMINED_FILES+="File: $FILE\n\n\`\`\`\n$(cat "$FILE")\n\`\`\`\n\n"
  else
    echo "File not found: $FILE"
    EXAMINED_FILES+="File: $FILE\n\nNot found in repository\n\n"
  fi
done

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
echo "$IMPLEMENT_PROMPT" | claude -p - > "$FIX_DETAILS_FILE"

# Parse Claude's response to extract file paths and changes
FILES_TO_MODIFY=$(grep -o "For file [^ ]*:" "$FIX_DETAILS_FILE" | sed -E 's/For file ([^:]*):$/\1/')

# Apply the changes to each file
for FILE_PATH in $FILES_TO_MODIFY; do
  echo "Processing changes for file: $FILE_PATH"
  
  # Extract the code block for this file
  FILE_BLOCK=$(sed -n "/For file $FILE_PATH:/,/^For file \|^[[:space:]]*$/p" "$FIX_DETAILS_FILE")
  
  # Check if we need to create a new file
  if [ ! -f "$FILE_PATH" ]; then
    # Get the content between the first code block markers
    NEW_CONTENT=$(echo "$FILE_BLOCK" | sed -n '/```/,/```/p' | sed '1d;$d')
    
    # Create directory if it doesn't exist
    mkdir -p "$(dirname "$FILE_PATH")"
    
    # Create the new file
    echo "$NEW_CONTENT" > "$FILE_PATH"
    echo "Created new file: $FILE_PATH"
  else
    # Extract diff blocks
    DIFF_BLOCKS=$(echo "$FILE_BLOCK" | grep -A100 "^```diff" | sed -n '/^```diff/,/^```/p' | sed '1d;$d')
    
    # Create a temporary file for the new content
    TEMP_FILE=$(mktemp)
    cat "$FILE_PATH" > "$TEMP_FILE"
    
    # Process each diff block
    echo "$DIFF_BLOCKS" | while IFS= read -r LINE; do
      if [[ "$LINE" == -* ]]; then
        # Remove line (strip the leading -)
        REMOVE_LINE="${LINE:1}"
        sed -i.bak "s|$REMOVE_LINE||g" "$TEMP_FILE"
      elif [[ "$LINE" == +* ]]; then
        # Add line (strip the leading +)
        ADD_LINE="${LINE:1}"
        # Find the line above where we need to add
        PREV_LINE=$(echo "$DIFF_BLOCKS" | grep -B1 "\\+$ADD_LINE" | head -n1)
        if [[ "$PREV_LINE" == -* ]]; then
          # Replace the removed line with the added line
          PREV_LINE="${PREV_LINE:1}"
          sed -i.bak "s|$PREV_LINE|$ADD_LINE|g" "$TEMP_FILE"
        else
          # Just append the line for now (this is simplistic)
          echo "$ADD_LINE" >> "$TEMP_FILE"
        fi
      fi
    done
    
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
PR_URL=$(gh pr create --title "Fix: $ISSUE_TITLE" --body "$PR_BODY" --base "$DEFAULT_BRANCH" --head "$FIX_BRANCH")

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

gh issue comment $ISSUE_NUMBER --body "$ISSUE_COMMENT"

# Clean up temp files
rm -f "$RESPONSE_FILE" "$FIX_DETAILS_FILE"

echo "Claude Code has created a fix for issue #$ISSUE_NUMBER in PR: $PR_URL"