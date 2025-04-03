# Claude Code GitHub Action

This GitHub Action integrates Claude, Anthropic's AI assistant, directly into your development workflow. It enables developers to get AI assistance directly within pull requests without switching contexts.

## Features

- Process user questions in PR comments with the `claude:` prefix
- Analyze PR changes and provide intelligent responses
- Provide rich context to Claude about the repository and PR
- Support for both Anthropic API and AWS Bedrock
- Simple integration with minimal configuration

## Usage

### Integration with PR Comments

Create a workflow that responds to comments starting with "claude:" in your pull requests:

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
        uses: fractureinc/claude-code-github-action@v0.1.4
        with:
          mode: 'review'
          pr-number: ${{ steps.pr.outputs.number }}
          feedback: ${{ steps.pr.outputs.feedback }}
          anthropic-api-key: ${{ secrets.ANTHROPIC_API_KEY }}
          github-token: ${{ secrets.GITHUB_TOKEN }}
          model-id: 'claude-3-7-sonnet-20250219'
```

## Configuration Options

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `mode` | Operation mode (review, direct) | Yes | `review` |
| `pr-number` | Pull request number | Yes* | |
| `feedback` | User query text | Yes | |
| `anthropic-api-key` | Anthropic API key | Yes | |
| `github-token` | GitHub token | Yes | |
| `model-id` | Claude model ID | No | `claude-3-7-sonnet-20250219` |
| `use-bedrock` | Use AWS Bedrock | No | `false` |
| `max-tokens` | Maximum response tokens | No | `4096` |
| `temperature` | Response temperature | No | `0.7` |
| `output-file` | Output file for direct mode | No | `claude-code-output` |

\* Required if mode is `review`

## Example Queries

Here are some example queries you can use with the `claude:` prefix:

- `claude: Explain the changes in this PR`
- `claude: Is there any way to optimize this code?`
- `claude: Suggest tests for these changes`
- `claude: Help me understand this algorithm`
- `claude: Review this PR for security issues`

## Using AWS Bedrock

To use Claude via AWS Bedrock instead of the Anthropic API:

```yaml
- name: Process with Claude Code via Bedrock
  uses: fractureinc/claude-code-github-action@v0.1.4
  with:
    mode: 'review'
    pr-number: ${{ steps.pr.outputs.number }}
    feedback: ${{ steps.pr.outputs.feedback }}
    github-token: ${{ secrets.GITHUB_TOKEN }}
    model-id: 'anthropic.claude-3-sonnet-20240229-v1:0'
    use-bedrock: true
  env:
    BEDROCK_AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
    BEDROCK_AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    BEDROCK_AWS_REGION: us-east-1
```

## How It Works

1. The action is triggered when a PR comment starting with `claude:` is detected
2. The action extracts the PR number and the query text
3. GitHub CLI is used to fetch detailed information about the PR and repository
4. Claude is provided with rich context about the repository, PR, and files changed
5. Claude processes the query and provides a response
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