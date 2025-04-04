# Claude Code GitHub Action

This GitHub Action integrates Claude Code in your GitHub workflows, enabling AI-assisted code reviews, suggestions, and automated fixes in both PRs and issues.

## Features

- Process PR and issue comments with different prefixes to trigger specific behaviors
- Get AI-powered code analysis and suggestions
- Create GitHub-compatible suggested changes that can be applied with one click
- Automatically analyze issues and create fix PRs
- Provide rich context about PRs and issues to Claude
- Simple setup with minimal configuration
- Uses GitHub CLI and Claude Code CLI for reliability

## Quick Start

### 1. Pull Request Interactions

Comment on a pull request:
- `claude: Explain the changes in this PR` → Get analysis and feedback
- `claude-suggest: Improve error handling` → Get code suggestions

Or use in-line code review:
- Comment on a specific line with `claude: What's wrong here?` → Get targeted analysis
- Comment on a specific line with `claude-suggest: Fix this` → Get targeted fix suggestions

### 2. Issue Interactions

Comment on an issue:
- `claude: What's causing this bug?` → Get analysis without changing code
- `claude-fix: Fix this by adding error handling` → Get a fix PR created automatically

Or add a label:
- Add the `claude-fix` label to an issue → Get a fix PR created automatically

## How to Use

Create a workflow file (`.github/workflows/claude-code.yml`) to enable Claude Code integration:

```yaml
name: Claude Code Integration

on:
  issue_comment:
    types: [created]
  pull_request_review_comment:
    types: [created]

jobs:
  # Standard Claude workflow configuration
  # (See full example below)
```

## Understanding Claude Code Modes

Claude Code can operate in several different modes, each with specific behaviors:

| Mode | Triggered By | Works On | Description |
|------|-------------|----------|-------------|
| `review` | `claude:` comment | PRs | Analyzes PR changes and responds with comments |
| `suggest` | `claude-suggest:` comment | PRs | Suggests code changes in PR comments |
| `suggest-review` | `claude-suggest:` code review comment | PR code line | Suggests in-line code changes that can be applied with one click |
| `issue-analyze` | `claude:` comment | Issues | Analyzes issues and responds with insights |
| `issue-fix` | `claude-fix:` comment or label | Issues | Creates a PR with code changes to fix the issue |
| `direct` | Direct action invocation | N/A | Runs Claude on arbitrary input and saves response to a file |

## Detailed Examples

### 1. PR Comments Workflow

```yaml
name: Claude Code Integration

on:
  issue_comment:
    types: [created]
  pull_request_review_comment:
    types: [created]

jobs:
  # Handle "claude:" comments on issues for analysis
  process-issue-analysis:
    runs-on: ubuntu-latest
    if: ${{ github.event_name == 'issue_comment' && !github.event.issue.pull_request && startsWith(github.event.comment.body, 'claude:') }}
    permissions:
      contents: read
      issues: write
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
      
      - name: Get issue details
        id: issue
        run: |
          ISSUE_NUMBER="${{ github.event.issue.number }}"
          FEEDBACK="${{ github.event.comment.body }}"
          # Remove the "claude:" prefix
          FEEDBACK="${FEEDBACK#claude:}"
          echo "number=$ISSUE_NUMBER" >> $GITHUB_OUTPUT
          echo "feedback=$FEEDBACK" >> $GITHUB_OUTPUT
      
      - name: Process with Claude Code for issue analysis
        uses: fractureinc/claude-code-github-action@v0.3.9
        with:
          mode: 'issue-analyze'
          issue-number: ${{ steps.issue.outputs.number }}
          repo-owner: ${{ github.repository_owner }}
          repo-name: ${{ github.event.repository.name }}
          feedback: ${{ steps.issue.outputs.feedback }}
          anthropic-api-key: ${{ secrets.ANTHROPIC_API_KEY }}
          github-token: ${{ secrets.GITHUB_TOKEN }}
          
  # Handle "claude-fix:" comments on issues to create fix PRs
  process-issue-fix-command:
    runs-on: ubuntu-latest
    if: ${{ github.event_name == 'issue_comment' && !github.event.issue.pull_request && startsWith(github.event.comment.body, 'claude-fix:') }}
    permissions:
      contents: write
      pull-requests: write
      issues: write
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
      
      - name: Setup GitHub CLI
        run: |
          gh auth login --with-token <<< "${{ secrets.GITHUB_TOKEN }}"

      - name: Setup git user
        run: |
          git config --global user.name "Claude Code Bot"
          git config --global user.email "claude-bot@example.com"
          
      - name: Get issue details
        id: issue
        run: |
          ISSUE_NUMBER="${{ github.event.issue.number }}"
          FEEDBACK="${{ github.event.comment.body }}"
          # Remove the "claude-fix:" prefix
          FEEDBACK="${FEEDBACK#claude-fix:}"
          echo "number=$ISSUE_NUMBER" >> $GITHUB_OUTPUT
          echo "feedback=$FEEDBACK" >> $GITHUB_OUTPUT
      
      - name: Process with Claude Code for issue fix
        uses: fractureinc/claude-code-github-action@v0.3.9
        with:
          mode: 'issue-fix'
          issue-number: ${{ steps.issue.outputs.number }}
          repo-owner: ${{ github.repository_owner }}
          repo-name: ${{ github.event.repository.name }}
          branch-prefix: 'fix'
          feedback: ${{ steps.issue.outputs.feedback }}
          anthropic-api-key: ${{ secrets.ANTHROPIC_API_KEY }}
          github-token: ${{ secrets.GITHUB_TOKEN }}
          
  # Handle "claude:" comments on PRs
  process-pr-review:
    runs-on: ubuntu-latest
    if: ${{ github.event_name == 'issue_comment' && github.event.issue.pull_request && startsWith(github.event.comment.body, 'claude:') }}
    permissions:
      contents: read
      pull-requests: write
      issues: write
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
      
      - name: Get PR details
        id: pr
        run: |
          PR_NUMBER="${{ github.event.issue.number }}"
          FEEDBACK="${{ github.event.comment.body }}"
          # Remove the "claude:" prefix
          FEEDBACK="${FEEDBACK#claude:}"
          echo "number=$PR_NUMBER" >> $GITHUB_OUTPUT
          echo "feedback=$FEEDBACK" >> $GITHUB_OUTPUT
      
      - name: Process with Claude Code
        uses: fractureinc/claude-code-github-action@v0.3.9
        with:
          mode: 'review'
          pr-number: ${{ steps.pr.outputs.number }}
          feedback: ${{ steps.pr.outputs.feedback }}
          anthropic-api-key: ${{ secrets.ANTHROPIC_API_KEY }}
          github-token: ${{ secrets.GITHUB_TOKEN }}

  # Handle "claude-suggest:" comments on PRs
  process-pr-suggestions:
    runs-on: ubuntu-latest
    if: ${{ github.event_name == 'issue_comment' && github.event.issue.pull_request && startsWith(github.event.comment.body, 'claude-suggest:') }}
    permissions:
      contents: read
      pull-requests: write
      issues: write
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
      
      - name: Get PR details
        id: pr
        run: |
          PR_NUMBER="${{ github.event.issue.number }}"
          FEEDBACK="${{ github.event.comment.body }}"
          # Remove the "claude-suggest:" prefix
          FEEDBACK="${FEEDBACK#claude-suggest:}"
          echo "number=$PR_NUMBER" >> $GITHUB_OUTPUT
          echo "feedback=$FEEDBACK" >> $GITHUB_OUTPUT
      
      - name: Process with Claude Code Suggestions
        uses: fractureinc/claude-code-github-action@v0.3.9
        with:
          mode: 'suggest'
          pr-number: ${{ steps.pr.outputs.number }}
          feedback: ${{ steps.pr.outputs.feedback }}
          anthropic-api-key: ${{ secrets.ANTHROPIC_API_KEY }}
          github-token: ${{ secrets.GITHUB_TOKEN }}
          
  # Handle "claude:" on code review comments  
  process-review-comment:
    runs-on: ubuntu-latest
    if: ${{ github.event_name == 'pull_request_review_comment' && startsWith(github.event.comment.body, 'claude:') }}
    permissions:
      contents: read
      pull-requests: write
      issues: write
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
      
      - name: Get PR and comment details
        id: details
        run: |
          PR_NUMBER="${{ github.event.pull_request.number }}"
          FEEDBACK="${{ github.event.comment.body }}"
          # Remove the "claude:" prefix
          FEEDBACK="${FEEDBACK#claude:}"
          COMMENT_ID="${{ github.event.comment.id }}"
          FILE_PATH="${{ github.event.comment.path }}"
          LINE="${{ github.event.comment.line }}"
          
          echo "number=$PR_NUMBER" >> $GITHUB_OUTPUT
          echo "feedback=$FEEDBACK" >> $GITHUB_OUTPUT
          echo "comment_id=$COMMENT_ID" >> $GITHUB_OUTPUT
          echo "file_path=$FILE_PATH" >> $GITHUB_OUTPUT
          echo "line=$LINE" >> $GITHUB_OUTPUT
      
      - name: Process with Claude Code for code review comment
        uses: fractureinc/claude-code-github-action@v0.3.9
        with:
          mode: 'review'
          pr-number: ${{ steps.details.outputs.number }}
          feedback: ${{ steps.details.outputs.feedback }}
          anthropic-api-key: ${{ secrets.ANTHROPIC_API_KEY }}
          github-token: ${{ secrets.GITHUB_TOKEN }}
          
  # Handle "claude-suggest:" on code review comments
  process-suggest-review-comment:
    runs-on: ubuntu-latest
    if: ${{ github.event_name == 'pull_request_review_comment' && startsWith(github.event.comment.body, 'claude-suggest:') }}
    permissions:
      contents: read
      pull-requests: write
      issues: write
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
      
      - name: Get PR and comment details
        id: details
        run: |
          PR_NUMBER="${{ github.event.pull_request.number }}"
          FEEDBACK="${{ github.event.comment.body }}"
          # Remove the "claude-suggest:" prefix
          FEEDBACK="${FEEDBACK#claude-suggest:}"
          COMMENT_ID="${{ github.event.comment.id }}"
          FILE_PATH="${{ github.event.comment.path }}"
          LINE="${{ github.event.comment.line }}"
          
          echo "number=$PR_NUMBER" >> $GITHUB_OUTPUT
          echo "feedback=$FEEDBACK" >> $GITHUB_OUTPUT
          echo "comment_id=$COMMENT_ID" >> $GITHUB_OUTPUT
          echo "file_path=$FILE_PATH" >> $GITHUB_OUTPUT
          echo "line=$LINE" >> $GITHUB_OUTPUT
      
      - name: Process with Claude Code Suggestions for code review
        uses: fractureinc/claude-code-github-action@v0.3.9
        with:
          mode: 'suggest-review'
          pr-number: ${{ steps.details.outputs.number }}
          feedback: ${{ steps.details.outputs.feedback }}
          file-path: ${{ steps.details.outputs.file_path }}
          line-number: ${{ steps.details.outputs.line }}
          comment-id: ${{ steps.details.outputs.comment_id }}
          strict-mode: 'true'
          anthropic-api-key: ${{ secrets.ANTHROPIC_API_KEY }}
          github-token: ${{ secrets.GITHUB_TOKEN }}
```

### 2. Issue Fix Workflow (Label-Based)

This workflow runs when issues are labeled with "claude-fix":

```yaml
name: Claude Code Issue Fix

on:
  issues:
    types: [labeled]

jobs:
  process-issue-fix:
    runs-on: ubuntu-latest
    # Run on issues with the configured label (default: 'claude-fix')
    if: ${{ github.event.label.name == 'claude-fix' }}
    permissions:
      contents: write
      pull-requests: write
      issues: write
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
      
      - name: Setup GitHub CLI
        run: |
          gh auth login --with-token <<< "${{ secrets.GITHUB_TOKEN }}"

      - name: Setup git user
        run: |
          git config --global user.name "Claude Code Bot"
          git config --global user.email "claude-bot@example.com"
          
      - name: Process issue with Claude Code
        uses: fractureinc/claude-code-github-action@v0.3.9
        with:
          mode: 'issue-fix'
          issue-number: ${{ github.event.issue.number }}
          repo-owner: ${{ github.repository_owner }}
          repo-name: ${{ github.event.repository.name }}
          branch-prefix: 'fix'
          issue-label: 'claude-fix'
          debug-mode: 'false'
          anthropic-api-key: ${{ secrets.ANTHROPIC_API_KEY }}
          github-token: ${{ secrets.GITHUB_TOKEN }}
```

This workflow is triggered when an issue is labeled with the configured label (default: "claude-fix"). You can customize this label using the `issue-label` parameter. Only repo maintainers with write access can add this label, providing security control.

## Query Prefixes and Their Behaviors

| Query Format | Where It Works | What It Does |
|--------------|----------------|-------------|
| `claude: <query>` | PR comments | Analyzes PR changes and responds as a comment |
| `claude-suggest: <query>` | PR comments | Suggests code changes in PR comments |
| `claude: <query>` | PR code review comments | Analyzes specific lines of code and responds as a comment |
| `claude-suggest: <query>` | PR code review comments | Creates in-line suggested changes |
| `claude: <query>` | Issue comments | Analyzes the issue and responds as a comment |
| `claude-fix: <query>` | Issue comments | Creates a PR with code changes to fix the issue |
| Adding the `claude-fix` label | Issues | Creates a PR with code changes to fix the issue |

## Configuration

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `mode` | Operation mode (review, suggest, suggest-review, issue-fix, issue-analyze, direct) | Yes | `review` |
| `pr-number` | Pull request number | Yes* | |
| `feedback` | User query text | Yes* | |
| `file-path` | Path to the file being reviewed (for suggest-review mode) | No** | |
| `line-number` | Line number in the file (for suggest-review mode) | No** | |
| `comment-id` | GitHub comment ID to reply to (for suggest-review mode) | No** | |
| `issue-number` | Issue number (for issue-fix mode) | Yes*** | |
| `repo-owner` | Owner of the repository (for issue-fix mode) | Yes*** | |
| `repo-name` | Name of the repository (for issue-fix mode) | Yes*** | |
| `branch-prefix` | Prefix for the feature branch created for issue fixes | No | `fix` |
| `issue-label` | Label that triggers issue fix workflows | No | `claude-fix` |
| `debug-mode` | Enable full debug mode with shell tracing and Claude debug output | No | `false` |
| `strict-mode` | Whether to strictly follow user requests without adding unrelated improvements | No | `true` |
| `anthropic-api-key` | Anthropic API key | Yes | |
| `github-token` | GitHub token | Yes | |
| `output-file` | Output file path (for direct mode) | No | `claude-code-output` |

\* Required when mode is 'review' or 'suggest'  
\** Required when mode is 'suggest-review'  
\*** Required when mode is 'issue-fix' or 'issue-analyze'

## Enhanced Context for Claude

With version 0.3.9, Claude now receives complete context for your PRs and issues, including:

- PR metadata (title, description, branch info)
- Issue details (title, description, labels)
- List of all files changed in PRs
- Complete diff of all changes in PRs
- Repository information (name, description, languages)
- Full repository checkout for improved code understanding and analysis
- User feedback with specific instructions

## Example Queries

### PR Comments

- `claude: Explain the changes in this PR`
- `claude: Suggest improvements for the code quality`
- `claude: Identify potential security issues`
- `claude: Is this implementation optimal?`
- `claude-suggest: Refactor this code to be more maintainable`
- `claude-suggest: Add error handling for edge cases`

### PR Code Review Comments

- `claude: What's the purpose of this function?`
- `claude: Is there a potential bug here?`
- `claude-suggest: Fix this loop to handle empty arrays`
- `claude-suggest: Optimize this database query`

### Issue Comments

- `claude: What might be causing this bug?`
- `claude: Analyze this error log and suggest potential fixes`
- `claude: How would you implement this feature?`
- `claude-fix: Implement proper error handling for division by zero`
- `claude-fix: Fix the memory leak in the connection pool`

## Permissions

Ensure your workflow has the appropriate permissions for each mode:

```yaml
# For review and suggest modes
permissions:
  contents: read
  pull-requests: write
  issues: write

# For issue-fix mode
permissions:
  contents: write  # Needed to create branches
  pull-requests: write  # Needed to create PRs
  issues: write  # Needed to comment on issues
```

## Security Considerations

- Only users with appropriate GitHub permissions can trigger Claude Code actions
- For issue fixes, using the label-based approach gives you more control over who can trigger code changes
- The `strict-mode` parameter limits Claude to only making requested changes

## License

MIT