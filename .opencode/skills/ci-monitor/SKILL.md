---
name: ci-monitor
description: Monitor GitHub Actions workflows, check build status, and get job logs
---

## What I do
- List workflow runs and their status
- Get details of failed jobs and their logs
- Re-run failed workflows
- Check CI status before merging PRs

## When to use me
Use this when asked about build status, CI/CD, workflow runs, failed builds, or GitHub Actions.

## API reference

### List workflow runs
```bash
curl -s -H "Authorization: Bearer $GITHUB_PERSONAL_ACCESS_TOKEN" \
  "https://api.github.com/repos/khanhvo-95/petstore/actions/runs?per_page=10"
```

### Get a specific run
```bash
curl -s -H "Authorization: Bearer $GITHUB_PERSONAL_ACCESS_TOKEN" \
  https://api.github.com/repos/khanhvo-95/petstore/actions/runs/<RUN_ID>
```

### List jobs for a run
```bash
curl -s -H "Authorization: Bearer $GITHUB_PERSONAL_ACCESS_TOKEN" \
  https://api.github.com/repos/khanhvo-95/petstore/actions/runs/<RUN_ID>/jobs
```

### Get job logs
```bash
curl -s -L -H "Authorization: Bearer $GITHUB_PERSONAL_ACCESS_TOKEN" \
  https://api.github.com/repos/khanhvo-95/petstore/actions/jobs/<JOB_ID>/logs
```

### Re-run failed jobs
```bash
curl -s -X POST \
  -H "Authorization: Bearer $GITHUB_PERSONAL_ACCESS_TOKEN" \
  https://api.github.com/repos/khanhvo-95/petstore/actions/runs/<RUN_ID>/rerun-failed-jobs
```

### Check commit status (for PR merge readiness)
```bash
curl -s -H "Authorization: Bearer $GITHUB_PERSONAL_ACCESS_TOKEN" \
  https://api.github.com/repos/khanhvo-95/petstore/commits/<SHA>/check-runs
```

## Workflow file
The CI/CD pipeline is defined in `.github/workflows/build-deploy.yml`.
It triggers on push to `master` and builds all microservices.

## Status interpretation
- `completed` + `success` — build passed
- `completed` + `failure` — build failed, check job logs
- `in_progress` — build is running
- `queued` — build is waiting to start
