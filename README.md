# Claude Code GitHub Action

This GitHub Action integrates Claude Code in your GitHub workflows, enabling AI-assisted code reviews, suggestions, and responses to PR comments.

## Features

- Process PR comments prefixed with "claude:" for general analysis
- Process PR comments prefixed with "claude-suggest:" for clickable code suggestions
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
        uses: fractureinc/claude-code-github-action@v0.2.0
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
        uses: fractureinc/claude-code-github-action@v0.2.0
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
| `mode` | Operation mode (review, suggest, direct) | Yes | `review` |
| `pr-number` | Pull request number | Yes* | |
| `feedback` | User query text | Yes | |
| `anthropic-api-key` | Anthropic API key | Yes | |
| `github-token` | GitHub token | Yes | |
| `output-file` | Output file path (for direct mode) | No | `claude-code-output` |

\* Required when mode is 'review' or 'suggest'

## Enhanced Context for Claude

With version 0.2.0, Claude now receives complete context for your PRs, including:

- PR metadata (title, description, branch info)
- List of all files changed
- Complete diff of all changes in the PR
- Repository information
- Full repository checkout for improved code understanding

## Available Modes

### Review Mode (`mode: 'review'`)

Standard mode that provides Claude's analysis and feedback about your PR changes as a comment.

### Suggest Mode (`mode: 'suggest'`)

Creates GitHub-compatible suggested changes that can be applied with one click directly from the PR interface.

### Direct Mode (`mode: 'direct'`)

Sends a query directly to Claude and saves the response to a file without PR context.

## Example Queries

### Review Mode Examples (prefix: `claude:`)

- `claude: Explain the changes in this PR`
- `claude: Can you suggest improvements to the code?`
- `claude: Are there any security issues in these changes?`
- `claude: How would you refactor this to be more maintainable?`
- `claude: What tests should be added for this code?`

### Suggest Mode Examples (prefix: `claude-suggest:`)

- `claude-suggest: Improve error handling in the API client`
- `claude-suggest: Fix any potential memory leaks`
- `claude-suggest: Optimize the database query on line 25`
- `claude-suggest: Make this code more readable`

## How It Works

1. The action is triggered when a comment with the appropriate prefix is detected on a PR
2. The action extracts the PR number and the user's query
3. The repository is checked out to provide full code context
4. Using GitHub CLI, the action fetches comprehensive information about the PR including:
   - PR metadata
   - List of files changed  
   - Complete diff of all changes
5. This rich context is provided to Claude along with the user's query
6. Claude processes the information and provides a helpful response
7. For review mode: The response is posted as a comment on the PR
8. For suggest mode: Claude formats responses as GitHub suggested changes that can be applied with one click

## Permissions

Ensure your workflow has these permissions:

```yaml
permissions:
  contents: read
  pull-requests: write
  issues: write
```

## License

MIT