# Claude Code GitHub Action

This GitHub Action integrates Claude Code into your workflows, enabling AI-assisted code reviews and intelligent responses to PR comments.

## Features

- Process user questions in PR comments
- Analyze pull request changes and provide intelligent reviews
- Use the latest Claude models from Anthropic
- Support for both Anthropic API and AWS Bedrock (Claude)

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
        uses: fractureinc/claude-code-github-action@v0.1.1
        with:
          mode: 'review'
          pr-number: ${{ steps.pr.outputs.number }}
          feedback: ${{ steps.pr.outputs.feedback }}
          anthropic-api-key: ${{ secrets.ANTHROPIC_API_KEY }}
          github-token: ${{ secrets.GITHUB_TOKEN }}
          model-id: 'claude-3-7-sonnet-20250219'
```

## Configuration Options

| Input             | Description                                      | Required | Default                   |
|-------------------|--------------------------------------------------|----------|---------------------------|
| `mode`            | Operation mode (review, direct)                  | Yes      | `review`                  |
| `pr-number`       | Pull request number                              | No       |                           |
| `feedback`        | User query text                                  | No       |                           |
| `anthropic-api-key` | Anthropic API key                              | Yes      |                           |
| `github-token`    | GitHub token for API access                      | Yes      |                           |
| `model-id`        | Claude model ID to use                           | No       | `claude-3-7-sonnet-20250219` |
| `use-bedrock`     | Use AWS Bedrock instead of Anthropic API         | No       | `false`                   |
| `max-tokens`      | Maximum response tokens                          | No       | `4096`                    |
| `temperature`     | Response temperature (0.0-1.0)                   | No       | `0.7`                     |
| `output-file`     | Output file path (for direct mode)               | No       | `claude-code-output`      |

## Using AWS Bedrock

To use Claude via AWS Bedrock instead of the Anthropic API, set `use-bedrock: true` and configure AWS credentials:

```yaml
- name: Process with Claude Code (Bedrock)
  uses: fractureinc/claude-code-github-action@v0.1.1
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

## Permissions

Ensure your workflow has the necessary permissions:

```yaml
permissions:
  contents: read
  pull-requests: write
  issues: write
```

## Debugging

If you encounter issues, check the workflow logs for detailed error messages. The action outputs the Claude prompt and response for debugging purposes.

## License

MIT