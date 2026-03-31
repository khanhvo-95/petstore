---
name: pr-merge
description: Merge pull requests after verifying CI status and reviews
---

## What I do
- Check PR mergeable status and CI checks
- Verify reviews are approved
- Merge the PR using the preferred merge method

## When to use me
Use this when asked to merge a PR, complete a pull request, or land changes to master.

## Steps

1. **Check PR status**
   ```bash
   curl -s -H "Authorization: Bearer $GITHUB_PERSONAL_ACCESS_TOKEN" \
     https://api.github.com/repos/khanhvo-95/petstore/pulls/<PR_NUMBER>
   ```
   - Verify `state` is `open`
   - Check `mergeable` is `true`
   - Check `mergeable_state` is not `dirty` (conflicts)

2. **Check CI status**
   ```bash
   curl -s -H "Authorization: Bearer $GITHUB_PERSONAL_ACCESS_TOKEN" \
     https://api.github.com/repos/khanhvo-95/petstore/commits/<HEAD_SHA>/check-runs
   ```
   - If checks are failing, report to user and do NOT merge
   - If checks are pending, ask user whether to wait

3. **Check reviews**
   ```bash
   curl -s -H "Authorization: Bearer $GITHUB_PERSONAL_ACCESS_TOKEN" \
     https://api.github.com/repos/khanhvo-95/petstore/pulls/<PR_NUMBER>/reviews
   ```
   - Warn if no reviews yet
   - Warn if there are `REQUEST_CHANGES` reviews

4. **Merge the PR**
   ```bash
   curl -s -X PUT \
     -H "Authorization: Bearer $GITHUB_PERSONAL_ACCESS_TOKEN" \
     -H "Accept: application/vnd.github+json" \
     https://api.github.com/repos/khanhvo-95/petstore/pulls/<PR_NUMBER>/merge \
     -d '{"merge_method":"squash"}'
   ```
   - Default merge method: `squash` (keeps master history clean)
   - Alternative methods: `merge`, `rebase` (if user requests)

5. **Confirm merge** and return the merge commit SHA

## Safety rules
- NEVER force merge if CI is failing
- NEVER merge if there are unresolved change requests
- Always confirm with the user before merging if there are warnings
