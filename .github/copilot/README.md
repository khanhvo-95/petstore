# 🤖 How to Use MCP in This Project

MCP (Model Context Protocol) lets Copilot **take real actions** — not just answer questions,
but actually create PRs, deploy to Azure, query logs, build Java projects, etc.

---

## 🔌 Your 3 MCP Servers

| # | Server | Config Location | What It Can Do |
|---|--------|----------------|----------------|
| 1 | **Azure MCP** | Global (`mcp.json`) | Query Azure resources, logs, deploy |
| 2 | **AppMod MCP** | Global (`mcp.json`) | Build Java, create Dockerfiles, upgrade deps |
| 3 | **GitHub MCP** | Project (`.github/copilot/mcp.json`) | PRs (create/review/merge), issues, branches, Actions, code security |

```
Global config (machine-specific, NOT committed):
  %LOCALAPPDATA%\github-copilot\intellij\mcp.json
  └── Azure MCP Server IntelliJ  (paths to IntelliJ plugin)
  └── appmod-mcp-server           (paths to IntelliJ plugin)

Project config (shared with team, committed to Git):
  .github/copilot/mcp.json
  └── github-mcp-server           (Docker-based, official GitHub MCP image)
      Toolsets: repos, issues, pull_requests, code_security, actions, context, users
```

---

## 1️⃣ Azure MCP — Manage Azure Resources

### What you can ask in Copilot Chat:

#### Query Resources
```
"List all container apps in demo-rg"
"Show me the resource groups in my subscription"
"What container registries do I have?"
```

#### Monitor & Logs
```
"Query App Insights for exceptions in the last hour"
"Show me the logs from petstore-app container"
"Run this KQL: traces | where timestamp > ago(1h) | limit 20"
```

#### Manage Resources
```
"Show the environment variables on my petstore-app container app"
"What is the status of demo-container-app-env?"
"List the revisions of petstore-app"
```

#### Pricing & Quotas
```
"What's the pricing for Container Apps in Southeast Asia?"
"Check my quota for Container Apps"
```

### Real Example — Query Exceptions:
> **You:** "Count exceptions with 'Cannot move further' in the last hour from App Insights"
>
> **Copilot** (via Azure MCP) → runs KQL query → returns count

---

## 2️⃣ AppMod MCP — Build, Dockerize, Upgrade Java

### What you can ask:

#### Build & Test
```
"Build the petstoreapp project"
"Run tests for petstoreorderservice"
"Check if the petstoreapp builds successfully"
```

#### Dockerize
```
"Generate a Dockerfile for petstoreapp"
"Create a containerization plan for all services"
"Analyze the repository structure"
```

#### Upgrade Java / Spring Boot
```
"Upgrade petstoreapp to Java 21"
"Upgrade Spring Boot to 3.5.x"
"Check for CVEs in my dependencies"
```

#### Deploy to Azure
```
"Create a deployment plan for all services to Container Apps"
"Generate Terraform for my container apps"
"Generate a CI/CD pipeline for GitHub Actions"
```

### Real Example — Build & Deploy:
> **You:** "Build petstoreapp and create a deployment plan for Azure Container Apps"
>
> **Copilot** (via AppMod MCP) → runs Maven build → generates plan in `.azure/plan.copilotmd`

---

## 3️⃣ GitHub MCP — PRs, Issues, Branches, Actions, Code Review

### Enabled Toolsets
The GitHub MCP server is configured with these toolsets:
`repos`, `issues`, `pull_requests`, `code_security`, `actions`, `context`, `users`

### What you can ask:

#### Pull Requests — Create, Review & Merge
```
"Create a PR from my current branch to master"
"List open pull requests"
"Show me the details of PR #5"
"Review PR #5 and approve it"
"Add a review comment on PR #5 requesting changes"
"Merge PR #5 using squash merge"
"Update PR #5 branch with latest from master"
"Get the files changed in PR #5"
"Get the review status of PR #5"
```

#### Code Review Workflow
```
"Review the changes in PR #5 and leave comments"
"Approve PR #5 with a comment"
"Request changes on PR #5 with feedback"
"Check the CI status of PR #5 before merging"
```

#### Issues
```
"Create an issue: Set up autoscaling for all services"
"List open issues"
"Close issue #3 with a comment"
```

#### Branches
```
"Create a new branch called feature/health-checks"
"List all branches"
```

#### GitHub Actions & CI/CD
```
"List workflow runs for the build-deploy workflow"
"Show me the latest failed workflow run"
"Get the logs for job #123"
"Re-run the failed workflow"
```

#### Code Security
```
"List code scanning alerts"
"Show me the details of security alert #1"
"Check for Dependabot alerts"
```

#### Repository
```
"Show me the latest commits"
"Search for files containing 'TelemetryClient'"
```

### Real Example — Full PR Workflow:
> **You:** "Create a PR titled 'Add App Insights to all services' with description of changes"
>
> **Copilot** (via GitHub MCP) → calls GitHub API → creates PR → returns URL
>
> **You:** "Review and approve PR #5, then merge it with squash"
>
> **Copilot** (via GitHub MCP) → reviews PR → approves → squash merges → confirms

---

## ⚡ Power Combos — Using Multiple MCPs Together

### Deploy a fix end-to-end:
```
1. "Build petstoreapp"                    → AppMod MCP builds it
2. "Create a branch fix/app-insights"     → GitHub MCP creates branch
3. "Deploy to Azure Container Apps"       → Azure MCP deploys
4. "Create a PR for this fix"             → GitHub MCP creates PR
5. "Check CI status of the PR"            → GitHub MCP checks Actions
6. "Review and approve the PR"            → GitHub MCP reviews
7. "Squash merge the PR"                  → GitHub MCP merges
```

### Diagnose & fix a production issue:
```
1. "Query App Insights for errors in the last hour"  → Azure MCP
2. "Show me the ProductManagementService code"        → Copilot reads file
3. "Fix the error and build"                          → AppMod MCP
4. "Create an issue to track this bug"                → GitHub MCP
```

### Upgrade and validate:
```
1. "Check for CVEs in petstoreapp dependencies"       → AppMod MCP
2. "Upgrade Spring Boot to latest"                    → AppMod MCP
3. "Build and run tests"                              → AppMod MCP
4. "Create a PR with the upgrade changes"             → GitHub MCP
```

---

## 📝 instructions.md — Automatic Project Context

**Location:** `.github/copilot/instructions.md`

This is NOT an MCP server — it's a **context file** that Copilot reads automatically
with every chat message. It tells Copilot:

- What services exist and their ports
- What tech stack you use
- Azure resource names (region, RG, ACR)
- Environment variables needed
- Coding conventions to follow

**Update it** whenever your architecture changes.

---

## 🔑 Setup for New Team Members

```powershell
# 1. Install Docker Desktop (required for GitHub MCP server)
#    https://www.docker.com/products/docker-desktop/

# 2. Create a GitHub PAT at https://github.com/settings/tokens?type=beta
#    Permissions needed:
#      - Contents (Read+Write)
#      - Pull requests (Read+Write)
#      - Issues (Read+Write)
#      - Actions (Read)
#      - Code scanning alerts (Read) — for code_security toolset
#      - Security events (Read) — for Dependabot alerts

# 3. Set it as a Windows environment variable
[System.Environment]::SetEnvironmentVariable(
  "GITHUB_PERSONAL_ACCESS_TOKEN", "github_pat_xxx", "User"
)

# 4. Restart IntelliJ — MCP servers connect automatically
#    Docker will pull ghcr.io/github/github-mcp-server on first use

# 5. Verify in Copilot Chat:
#    "List my Azure resource groups"        → Tests Azure MCP
#    "List open PRs on this repo"           → Tests GitHub MCP
#    "Review PR #1"                         → Tests PR review
#    "Build petstoreapp"                    → Tests AppMod MCP
```

---

## 🗂 File Reference

| File | Purpose |
|------|---------|
| `.github/copilot/mcp.json` | Project-level MCP config (GitHub server) |
| `.github/copilot/instructions.md` | Project context for Copilot |
| `.github/copilot/README.md` | This guide |
| `.github/workflows/build-deploy.yml` | CI/CD pipeline |
| `%LOCALAPPDATA%\github-copilot\intellij\mcp.json` | Global MCP config (Azure + AppMod + GitHub) |
