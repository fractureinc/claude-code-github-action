# Claude Code GitHub Action

This GitHub Action integrates Claude Code in your GitHub workflows, enabling AI-assisted code reviews and responses to PR comments.

## Features

- Process PR comments prefixed with "claude:"
- Provide rich context about the PR to Claude, including file diffs
- Get AI-powered code analysis and suggestions
- Simple setup with minimal configuration
- Uses GitHub CLI and Claude Code CLI for reliability

## Usage

Create a workflow file that responds to comments containing the "claude:" prefix:

```yaml
name: Claude Code Integration

on:
  issue_comment:
    types: [created]
  pull_request_review_comment:
    types: [created]

jobs:
  process-pr-comment:
    runs-on: ubuntu-latest
    if: ${{ github.event_name == 'issue_comment' && github.event.issue.pull_request && startsWith(github.event.comment.body, 'claude:') }}
    permissions:
      contents: read
      pull-requests: write
      issues: write
    steps:
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
        uses: fractureinc/claude-code-github-action@v0.1.6
        with:
          mode: 'review'
          pr-number: ${{ steps.pr.outputs.number }}
          feedback: ${{ steps.pr.outputs.feedback }}
          anthropic-api-key: ${{ secrets.ANTHROPIC_API_KEY }}
          github-token: ${{ secrets.GITHUB_TOKEN }}
```

## Configuration

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `mode` | Operation mode (review or direct) | Yes | `review` |
| `pr-number` | Pull request number | Yes* | |
| `feedback` | User query text | Yes | |
| `anthropic-api-key` | Anthropic API key | Yes | |
| `github-token` | GitHub token | Yes | |
| `output-file` | Output file path (for direct mode) | No | `claude-code-output` |

\* Required when mode is 'review'

## Enhanced Context for Claude

With version 0.1.6, Claude now receives complete context for your PRs, including:

- PR metadata (title, description, branch info)
- List of all files changed
- Complete diff of all changes in the PR
- Repository information

This allows Claude to provide much more accurate and helpful responses about your code changes.

## Example Queries

Here are some example queries you can use with the claude: prefix:

- `claude: Explain the changes in this PR`
- `claude: Can you suggest improvements to the code?`
- `claude: Are there any security issues in these changes?`
- `claude: How would you refactor this to be more maintainable?`
- `claude: What tests should be added for this code?`

## How It Works

1. The action is triggered when a comment starting with "claude:" is detected on a PR
2. The action extracts the PR number and the user's query
3. Using GitHub CLI, the action fetches comprehensive information about the PR including:
   - PR metadata
   - List of files changed  
   - Complete diff of all changes
4. This rich context is provided to Claude along with the user's query
5. Claude processes the information and provides a helpful response
6. The response is posted as a comment on the PR

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