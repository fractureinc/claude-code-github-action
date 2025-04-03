# Claude Code GitHub Action

This GitHub Action integrates Claude Code within your GitHub workflows, enabling AI-assisted code reviews and answering questions in PR comments.

## Usage

### Basic PR Comment Integration

```yaml
name: Claude Code Integration

on:
  issue_comment:
    types: [created]

jobs:
  claude-code:
    if: contains(github.event.comment.body, 'claude:')
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
      issues: write
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
      
      - name: Run Claude Code
        uses: fractureinc/claude-code-github-action@v0.1.1
        with:
          mode: pr-comment
          pr-url: ${{ github.event.issue.pull_request.url }}
          version: claude-3-opus-20240229
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
```

## Inputs

| Name | Description | Required | Default |
|------|-------------|----------|---------|
| `mode` | The mode to run the action in (`pr-comment`, `comment`, `direct`) | Yes | `pr-comment` |
| `version` | The Claude model version | No | `claude-3-opus-20240229` |
| `system-prompt` | Custom system prompt | No | |
| `github-token` | GitHub token | No | `${{ github.token }}` |
| `pr-url` | URL of the PR (for `pr-comment` mode) | No | |
| `comment` | Comment text (for `comment` mode) | No | |
| `request` | Direct request to Claude (for `direct` mode) | No | |
| `model-provider` | Model provider (`anthropic` or `bedrock`) | No | `anthropic` |
| `max-tokens` | Maximum tokens to generate | No | `4096` |
| `temperature` | Generation temperature | No | `0.7` |
| `output-file` | Path to write output | No | `claude-code/issue` |

## Authentication

For Anthropic API access:
```yaml
env:
  ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
```

For AWS Bedrock:
```yaml
env:
  BEDROCK_AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
  BEDROCK_AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
  BEDROCK_AWS_REGION: us-east-1
```

## License

MIT