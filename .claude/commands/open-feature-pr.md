---
description: Plan, implement a feature, run tests, commit, and open a PR
allowed-tools: Bash(git add:*), Bash(git commit:*), Bash(git checkout:*), Bash(git switch:*), Bash(git push:*), Bash(gh pr create:*), Bash(gh:*), Edit
---

Plan and implement the feature described as: "$ARGUMENTS".

1) Create and switch to a new branch named feature/<slug based on "$ARGUMENTS">.
2) List the files to change and the rationale.
3) Implement in small steps, staging/committing as we go.
4) Run tests: `mix test` and JS tests (`npm test`, but only if there are front end changes). Iterate until green.
5) Push the branch and **open a PR** with `gh pr create` including a solid title/body, test plan, and reviewers.

Be explicit and show me the final PR URL.

## Context
- Current git status: !`git status --porcelain`
- Current branch: !`git branch --show-current`
- Recent commits: !`git log --oneline -10`
