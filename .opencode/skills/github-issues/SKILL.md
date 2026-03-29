---
name: github-issues
description: Create, update, list, and close GitHub issues
---

## What I do
- Create new issues with labels and descriptions
- List and filter open/closed issues
- Update issue status and add comments
- Close issues with resolution comments

## When to use me
Use this when asked to create an issue, list issues, close an issue, or manage GitHub issues.

## API reference

### List issues
```bash
curl -s -H "Authorization: Bearer $GITHUB_PERSONAL_ACCESS_TOKEN" \
  "https://api.github.com/repos/khanhvo-95/petstore/issues?state=open&per_page=30"
```

### Create issue
```bash
curl -s -X POST \
  -H "Authorization: Bearer $GITHUB_PERSONAL_ACCESS_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/khanhvo-95/petstore/issues \
  -d '{"title":"Issue title","body":"Description","labels":["bug"]}'
```

### Update issue (close)
```bash
curl -s -X PATCH \
  -H "Authorization: Bearer $GITHUB_PERSONAL_ACCESS_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/khanhvo-95/petstore/issues/<NUMBER> \
  -d '{"state":"closed"}'
```

### Add comment
```bash
curl -s -X POST \
  -H "Authorization: Bearer $GITHUB_PERSONAL_ACCESS_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/khanhvo-95/petstore/issues/<NUMBER>/comments \
  -d '{"body":"Comment text"}'
```

## Label conventions
- `bug` — something is broken
- `enhancement` — new feature request
- `chore` — maintenance task
- `documentation` — docs update needed
