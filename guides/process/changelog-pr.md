# PR processes

## Story, Bug, and Task development

1. Create one integration branch from `master` for the parent Jira Story, Bug, or Task, using `story/*`, `bug/*`, or `task/*` respectively. Existing `integ-*` branches follow the same process. Enable integration branch protections: require a PR, code review approvals, and status checks; block direct pushes. See [Integration Branches](deployment.md#integration-branches).
2. Track all developer work in child Sub-tasks of that parent ticket, including work for a small bug fix or chore. Create each `sub-task/*` implementation branch from the integration branch and open its PR against that integration branch. Developers do not commit directly to integration branches or open implementation PRs against `master`.
3. Review each implementation PR, resolve requested changes, and wait for all required approvals and checks. **Squash and merge** the approved PR into the integration branch. Prefix its commit message with the change type, Sub-task ticket reference, and description, for example `[BUG FIX] [MER-1001] Fix dashboard loading`.
4. Once all Sub-tasks have merged and the parent ticket's acceptance criteria pass, open a PR from the integration branch to `master`, referencing the parent Jira ticket. Obtain the required reviews and status checks, then submit the PR to the `master` merge queue.
5. The queue tests the proposed merge against the latest `master` and earlier queued changes. If conflicts prevent merging, create a `sync/*` branch from the integration branch, merge `master` into it, and resolve the conflicts there. Track this work in a child Sub-task and open a sync PR against the integration branch. After approvals and checks pass, merge the sync PR with a **merge commit**, then submit the integration PR to the `master` merge queue again. See [Syncing an integration branch](deployment.md#keeping-an-integration-branch-in-sync-with-master).

The **Validate master source branch** check allows only `integ-*`, `story/*`, `bug/*`, `task/*`, and `dependabot/*`, case-insensitively. `sub-task/*` and `sync/*` branches target their integration branch and cannot merge directly into `master`. Dependabot remains an automated dependency-update exception to the developer Sub-task workflow.

Configure your [Jira branch-name preference](deployment.md#jira-branch-name-preference) to suggest `Issue type / Issue key - Issue summary` in the Git command. The **Create branch in GitHub** dialog does not use that preference; add the prefix manually or paste the branch name from the suggestion. Before using a new integration prefix, confirm the [ruleset and CI rollout requirements](deployment.md#rollout-requirements) are complete.

### Valid Change Types

- `[FEATURE]`: New feature for the user
- `[ENHANCEMENT]`: Small improvements to existing features
- `[BUG FIX]`: Bug fix for an existing feature
- `[CHORE]`: Updating of build infrastructure, deployment automation, branch merging, docs, etc.
- `[PERFORMANCE]`: Changes that target a performance improvement

### Valid ticket references

- `[MER-xxxx]`: MER board tickets
- `[NG23-xxxx]`: NG board tickets
