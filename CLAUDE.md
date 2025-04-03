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

## Future Features

- Code change functionality (planned)
- Additional modes for different types of Claude integration
- Support for custom prompts and templates