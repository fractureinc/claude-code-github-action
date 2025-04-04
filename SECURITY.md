# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it by creating a new issue labeled "security". 

For sensitive security matters that should not be disclosed publicly, please contact the maintainers directly.

## Guidelines

* Provide as much information as possible about the vulnerability
* Include steps to reproduce if applicable
* If you have a suggested fix, feel free to mention it

## Our Commitment

We take security seriously and will:

* Acknowledge receipt of your vulnerability report in a timely manner
* Verify the vulnerability and determine its impact
* Release patches as quickly as possible for confirmed vulnerabilities

## Security Best Practices for Users

When using this GitHub Action:

1. Always pin to a specific version rather than using `@main` to avoid unexpected changes
2. Use the least privileged GitHub token permissions needed for your workflow
3. Be cautious when using the `issue-fix` mode which can modify code
4. Use the label-based approach for issue fixes to limit who can trigger code changes
5. Keep your Anthropic API key secure