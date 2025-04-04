# Claude Information

This document contains important information for Claude when working with this repository.

## Project Overview

This GitHub Action integrates Claude Code with GitHub workflows, enabling AI-assisted code reviews and responses to PR comments. The action provides rich PR context to Claude, including complete diffs of all changes, allowing for detailed analysis and feedback.

## Commands to Run

When making changes, please run the following commands to verify everything works correctly:

- `git status` - Check the status of files
- `git diff` - Review your changes
- `npm version patch` - To increment the version number (when appropriate)

## Design Principles

1. **Simplicity** - Keep the action simple and focused on its core purpose
2. **Reliability** - Use established tools like GitHub CLI and Claude Code CLI
3. **Rich Context** - Always provide comprehensive context to Claude for better analysis
4. **Minimal Dependencies** - Avoid unnecessary dependencies to keep the action lightweight

## Key Files

- `action.yml` - Core definition of the GitHub Action
- `package.json` - Project metadata including version
- `README.md` - Documentation and usage examples

## Current Version

The current version is stored in package.json and should be updated when making significant changes. 
Remember to update both:
1. Version number in package.json
2. Version reference in README.md examples
3. Create a git tag matching the version

## Implementation Plan for Code Modification

We're implementing several approaches for Claude to make code changes:

1. **Suggested Changes Mode (Priority 1)**
   - Claude generates code suggestions formatted as GitHub suggested changes
   - Developers can review and apply with one click
   - Safest approach but limited to smaller changes

2. **Two-step Approval (Priority 2)**
   - Claude proposes changes in a comment
   - Developer must explicitly approve with a follow-up command
   - Only then are changes committed and pushed
   - Example: "claude-approve: [reference ID]"

3. **Draft PR Approach (Priority 3)**
   - Create a separate branch with Claude's changes
   - Open a draft PR against the original PR branch
   - Completely isolates changes for review

4. **Special Command Prefix (Priority 4)**
   - Regular comments: "claude: [question]" → just get a response
   - For changes: "claude-fix: [request]" → makes and commits changes
   - Clear differentiation of intent

## Future Features

- Additional modes for different types of Claude integration
- Support for custom prompts and templates