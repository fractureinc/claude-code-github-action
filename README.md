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

### 1. Add Claude to Your Repository

Create two simple workflow files to integrate Claude with your repository:

**File: `.github/workflows/claude-code.yml`**
```yaml
name: Claude Code Integration

on:
  issue_comment:
    types: [created]
  pull_request_review_comment:
    types: [created]

jobs:
  claude-integration:
    uses: fractureinc/claude-code-github-action/.github/workflows/claude-full.yml@v0.5.4
    with:
      issue-label: 'claude-fix'  # Optional: customize the trigger label
    secrets:
      ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
```

**File: `.github/workflows/claude-issue-fix.yml`**
```yaml
name: Claude Code Issue Fix

on:
  issues:
    types: [labeled]

jobs:
  claude-label-fix:
    uses: fractureinc/claude-code-github-action/.github/workflows/claude-label-fix.yml@v0.5.4
    with:
      issue-label: 'claude-fix'  # Must match your chosen label
    secrets:
      ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
```

### 2. Use Claude in PRs and Issues

Comment on a pull request:
- `claude: Explain the changes in this PR` → Get analysis and feedback
- `claude-suggest: Improve error handling` → Get code suggestions

Or use in-line code review:
- Comment on a specific line with `claude: What's wrong here?` → Get targeted analysis
- Comment on a specific line with `claude-suggest: Fix this` → Get targeted fix suggestions

Comment on an issue:
- `claude: What's causing this bug?` → Get analysis without changing code
- `claude-fix: Fix this by adding error handling` → Get a fix PR created automatically

Or add a label:
- Add the `claude-fix` label to an issue → Get a fix PR created automatically

## Setup Details

The Quick Start section above shows the minimal configuration needed. Our action uses reusable workflows to make setup easy - you just need to create two small workflow files that reference our pre-configured workflows.

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

## Advanced Configuration

The reusable workflows support several configuration options:

### Comment-Based Integration (`claude-full.yml`)

```yaml
jobs:
  claude-integration:
    uses: fractureinc/claude-code-github-action/.github/workflows/claude-full.yml@v0.5.4
    with:
      # All parameters are optional with sensible defaults
      issue-label: 'claude-fix'  # Label that triggers issue fixes
      branch-prefix: 'fix'       # Prefix for branches created by fixes
      debug-mode: false          # Enable verbose logging
      strict-mode: true          # When false, allows Claude to add improvements
    secrets:
      ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
```

### Label-Based Integration (`claude-label-fix.yml`)

```yaml
jobs:
  claude-label-fix:
    uses: fractureinc/claude-code-github-action/.github/workflows/claude-label-fix.yml@v0.5.4
    with:
      # All parameters are optional with sensible defaults
      issue-label: 'claude-fix'  # Must match the label you're using
      branch-prefix: 'fix'       # Prefix for branches created by fixes
      debug-mode: false          # Enable verbose logging
    secrets:
      ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
```

Only repo maintainers with write access can add labels, providing security control over which issues Claude will fix.

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

## Configuration Options

When using our reusable workflows, you only need to configure a few key options:

| Parameter | Description | Default | Used In |
|-----------|-------------|---------|---------|
| `issue-label` | Label that triggers issue fixes | `claude-fix` | Both workflows |
| `branch-prefix` | Prefix for branches created by fixes | `fix` | Both workflows |
| `debug-mode` | Enable verbose logging | `false` | Both workflows |
| `strict-mode` | Controls whether Claude adds improvements beyond what's requested | `true` | Comment workflow only |

All parameters are optional and have sensible defaults.

## Enhanced Context for Claude

With version 0.5.4, Claude now receives complete context for your PRs and issues, including:

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