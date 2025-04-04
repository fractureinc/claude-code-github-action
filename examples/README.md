# Examples for Claude Code GitHub Action

This directory contains example files for testing different features of the Claude Code GitHub Action.

## Calculator.js

A simple calculator implementation with several code issues that can be improved using Claude's suggestions:

- Missing input validation
- No error handling for division by zero
- Inefficient power calculation
- Poor function naming
- Recursive factorial without safety checks

## Usage

To use the Claude Code GitHub Action with these examples:

1. Comment on specific lines with `claude-suggest:` followed by your request
2. Claude will analyze the code and provide inline suggestions you can apply with one click
3. For general code review, use `claude:` followed by your question about the code

Example comments:
- `claude-suggest: Add input validation to this method`
- `claude-suggest: Fix the division method to handle zero`
- `claude-suggest: Improve the variable naming in this function`
- `claude: What issues do you see with this factorial implementation?`