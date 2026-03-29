---
name: pr-review
description: Review pull requests with structured code feedback, approve or request changes
---

## What I do
- Fetch PR details and list of changed files
- Analyze code changes for bugs, security issues, and style problems
- Submit a review with approve, request changes, or comment

## When to use me
Use this when asked to review a PR, check a pull request, or provide code feedback.

## Steps

1. **Get PR details**
   ```bash
   curl -s -H "Authorization: Bearer $GITHUB_PERSONAL_ACCESS_TOKEN" \
     https://api.github.com/repos/khanhvo-95/petstore/pulls/<PR_NUMBER>
   ```

2. **Get changed files**
   ```bash
   curl -s -H "Authorization: Bearer $GITHUB_PERSONAL_ACCESS_TOKEN" \
     https://api.github.com/repos/khanhvo-95/petstore/pulls/<PR_NUMBER>/files
   ```

3. **Analyze each file** — check for:
   - Bugs or logic errors
   - Security concerns (hardcoded secrets, SQL injection, etc.)
   - Missing error handling or logging
   - Java 17+ conventions (Jakarta namespace, records, text blocks)
   - Spring Boot 3.x patterns
   - Missing tests for new functionality

4. **Submit review**
   ```bash
   curl -s -X POST \
     -H "Authorization: Bearer $GITHUB_PERSONAL_ACCESS_TOKEN" \
     -H "Accept: application/vnd.github+json" \
     https://api.github.com/repos/khanhvo-95/petstore/pulls/<PR_NUMBER>/reviews \
     -d '{"event":"APPROVE","body":"LGTM! Changes look good."}'
   ```
   - Use `APPROVE` if code looks good
   - Use `REQUEST_CHANGES` if issues found
   - Use `COMMENT` for general feedback without blocking

5. **Report findings** to the user with a summary

## Review checklist
- [ ] No hardcoded secrets or URLs (use env vars)
- [ ] Proper error handling with SLF4J logging
- [ ] Application Insights telemetry for new features
- [ ] Environment variables for external service URLs
- [ ] Spring Boot 3.x / Jakarta conventions
- [ ] Docker/container compatibility maintained
