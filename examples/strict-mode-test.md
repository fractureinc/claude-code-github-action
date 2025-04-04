# Testing Strict Mode Feature

This file provides examples for testing the strict mode feature in claude-code-github-action.

## About Strict Mode

When strict mode is enabled (default), Claude will only address the specific issue mentioned in the comment without making unrelated improvements. When disabled, Claude may suggest additional improvements beyond what was explicitly requested.

## Test Cases

### Test 1: Adding a Feature (with strict mode)

Comment on line 19 in `todo-app.js`:
```
claude-suggest: Add a filter method to allow filtering todos by completed status
```

This should produce a suggestion that just adds the requested filter method, without modifying other parts of the code.

### Test 2: Adding a Feature (without strict mode)

Add this to the workflow file when testing:
```yaml
strict-mode: 'false'
```

Then comment on line 19 in `todo-app.js`:
```
claude-suggest: Add a filter method to allow filtering todos by completed status
```

This may produce both the requested filter method AND additional improvements to other parts of the code.

### Test 3: Improving Variables

Comment on line 35 in `todo-app.js` where the `var` is used:
```
claude-suggest: Use let instead of var
```

In strict mode, it should only change the specific variable declaration.
In non-strict mode, it might change all var declarations in the file.

## Expected Outcomes

1. In strict mode, Claude should address ONLY what was explicitly requested
2. In non-strict mode, Claude may offer additional improvements
3. The non-strict mode should provide a separate comment with additional suggestions