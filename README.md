# Claude Code GitHub Action

This GitHub Action integrates Claude Code in your GitHub workflows, enabling AI-assisted code reviews, suggestions, and responses to PR comments.

## Features

- Process PR comments prefixed with "claude:" for general analysis
- Process PR comments prefixed with "claude-suggest:" for code suggestions
- Process code review comments to provide in-line analysis and suggestions
- Automatically analyze issues and create fix PRs based on issue labels
- Provide rich context about the PR to Claude, including file diffs
- Get AI-powered code analysis and suggestions
- Create GitHub-compatible suggested changes that can be applied with one click
- Simple setup with minimal configuration
- Uses GitHub CLI and Claude Code CLI for reliability

## Usage

Create a workflow file (`.github/workflows/claude-code.yml`) that responds to comments with the appropriate prefixes:

```yaml
name: Claude Code Integration

on:
  issue_comment:
    types: [created]

jobs:
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
        uses: fractureinc/claude-code-github-action@v0.3.8
        with:
          mode: 'review'
          pr-number: ${{ steps.pr.outputs.number }}
          feedback: ${{ steps.pr.outputs.feedback }}
          anthropic-api-key: ${{ secrets.ANTHROPIC_API_KEY }}
          github-token: ${{ secrets.GITHUB_TOKEN }}

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
        uses: fractureinc/claude-code-github-action@v0.3.8
        with:
          mode: 'suggest'
          pr-number: ${{ steps.pr.outputs.number }}
          feedback: ${{ steps.pr.outputs.feedback }}
          anthropic-api-key: ${{ secrets.ANTHROPIC_API_KEY }}
          github-token: ${{ secrets.GITHUB_TOKEN }}
```

## Configuration

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `mode` | Operation mode (review, suggest, suggest-review, issue-fix, direct) | Yes | `review` |
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
\*** Required when mode is 'issue-fix'

## Enhanced Context for Claude

With version 0.3.8, Claude now receives complete context for your PRs and issues, including:

- PR metadata (title, description, branch info)
- Issue details (title, description, labels)
- List of all files changed in PRs
- Complete diff of all changes in PRs
- Repository information (name, description, languages)
- Full repository checkout for improved code understanding and analysis

## Available Modes

### Review Mode (`mode: 'review'`)

Standard mode that provides Claude's analysis and feedback about your PR changes as a comment.

### Suggest Mode (`mode: 'suggest'`)

Creates suggested changes in a PR comment that outline potential code improvements.

### Suggest Review Mode (`mode: 'suggest-review'`)

Creates true GitHub-compatible suggestions that can be applied with one click directly from the code review interface. These are attached to specific lines of code.

By default, this mode uses "strict mode" which ensures Claude only makes changes specifically related to what was requested, without adding unrelated improvements. You can disable strict mode by setting `strict-mode: 'false'` to allow Claude to suggest additional improvements.

### Issue Fix Mode (`mode: 'issue-fix'`)

Analyzes GitHub issues labeled with "claude-fix" and automatically creates a PR with proposed fixes. This mode:
- Analyzes the issue description to understand the problem
- Identifies affected files in the codebase
- Implements code changes to fix the issue
- Creates a branch with the changes
- Opens a PR with detailed explanation
- Comments on the original issue with a link to the PR

### Direct Mode (`mode: 'direct'`)

Sends a query directly to Claude and saves the response to a file without PR context.

## Example Queries

### Review Mode Examples (prefix: `claude:`)

- `claude: Explain the changes in this PR`
- `claude: Can you suggest improvements to the code?`
- `claude: Are there any security issues in these changes?`
- `claude: How would you refactor this to be more maintainable?`
- `claude: What tests should be added for this code?`
- `claude: Analyze the performance implications of these changes`

### Suggest Mode Examples (prefix: `claude-suggest:`)

- `claude-suggest: Improve error handling in the API client`
- `claude-suggest: Fix any potential memory leaks`
- `claude-suggest: Optimize the database query on line 25`
- `claude-suggest: Make this code more readable`

## How It Works

1. The action is triggered when a comment with the appropriate prefix is detected (either on the PR or in code review)
2. The action extracts the PR number, user's query, and (for code review comments) the file path and line number
3. The repository is checked out to provide full code context
4. Using GitHub CLI, the action fetches comprehensive information about the PR including:
   - PR metadata
   - List of files changed
   - Complete diff of all changes
   - For code review comments, specific file content and context around the commented line
5. This rich context is provided to Claude along with the user's query
6. Claude processes the information and provides a helpful response
7. For review mode: The response is posted as a comment on the PR
8. For suggest mode: Claude formats responses with code suggestions in the PR comment
9. For suggest-review mode: Claude creates true GitHub-compatible suggestions attached to specific lines of code

## Permissions

Ensure your workflow has these permissions:

```yaml
permissions:
  contents: read
  pull-requests: write
  issues: write
```

## Issue Fix Workflow

Create a workflow file (`.github/workflows/claude-issue-fix.yml`) that responds to issues labeled with "claude-fix":

```yaml
name: Claude Code Issue Fix

on:
  issues:
    types: [labeled]

jobs:
  process-issue-fix:
    runs-on: ubuntu-latest
    # Only run on issues with the 'claude-fix' label
    if: ${{ github.event.label.name == 'claude-fix' }}
    permissions:
      contents: write  # Needed to create branches
      pull-requests: write  # Needed to create PRs
      issues: write  # Needed to comment on issues
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
        uses: fractureinc/claude-code-github-action@v0.3.8
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

## License

MIT