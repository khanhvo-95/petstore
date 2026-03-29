---
name: pr-create
description: Create pull requests with proper title, description, and branch setup
---

## What I do
- Verify the current branch has commits ahead of the base branch
- Ensure all changes are committed and pushed to remote
- Create a pull request with a structured description

## When to use me
Use this when asked to create a PR, open a pull request, or submit code for review.

## Steps

1. **Check branch state**
   - Run `git status` to confirm no uncommitted changes
   - Run `git log <base>...HEAD --oneline` to see commits to include
   - If there are uncommitted changes, ask the user whether to commit first

2. **Push to remote**
   - Check if the branch tracks a remote: `git status -sb`
   - If not pushed, run `git push -u origin <branch-name>`

3. **Create the PR**
   - Use the GitHub API via curl with `$GITHUB_PERSONAL_ACCESS_TOKEN`
   - Target base branch: `master` (unless user specifies otherwise)
   - Title format: `<type>: <short description>` (e.g., `feat:`, `fix:`, `chore:`)
   - Body should include:
     - `## Summary` — bullet points of what changed and why
     - `## Files Changed` — table of key files
     - Link to related issues if any

4. **Return the PR URL** to the user

## Repository info
- Owner: `khanhvo-95`
- Repo: `petstore`
- Default base branch: `master`
- API: `https://api.github.com/repos/khanhvo-95/petstore/pulls`

## Example API call
```bash
curl -s -X POST \
  -H "Authorization: Bearer $GITHUB_PERSONAL_ACCESS_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/khanhvo-95/petstore/pulls \
  -d '{"title":"feat: add feature X","head":"feature/branch","base":"master","body":"## Summary\n- Added X"}'
```
