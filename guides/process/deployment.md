# CI/CD and Deployment Process

## Overview

Torus uses Github Actions for its CI/CD pipelines. When a PR is opened, a build is automatically started and several checks are run including unit tests and lint checks which must all pass before a PR can be merged. Once a branch is merged into master, the resulting commit is packaged and deployed to the test server ([tokamak.oli.cmu.edu](https://tokamak.oli.cmu.edu)). The test server will always represent the latest from master unless a manual deployment is made. When a release is made (tagged vX.Y.Z), a deployment is kicked off to the production server ([proton.oli.cmu.edu](proton.oli.cmu.edu)). A production deployment will always use a prebuilt artifact identified by the version and commit SHA to ensure that the release tested is the same as the release deployed.

**Test Server:** [tokamak.oli.cmu.edu](tokamak.oli.cmu.edu)

**Production Server:** [proton.oli.cmu.edu](proton.oli.cmu.edu)

## Pull Requests

Every pull request is required to pass a set of status checks in both Elixir and Typescript including a successful build, all unit tests passing, and successful lint with no errors (TypeScript). These checks are automatically started when a pull request is created. Other automated checks include Coveralls for unit test coverage and GitGuardian for identifying accidentally leaked secrets, however these checks are only informative and discretion is left to the developer and code reviewer to decide if issues found are blocking.

PRs targeting `master` must also pass **Validate master source branch**. The source branch must match `integ-*`, `story/*`, `bug/*`, `task/*`, or `dependabot/*`, case-insensitively. This check runs when the PR is opened, updated with new commits, reopened, or edited. It checks the source branch name; it does not verify the Jira issue type. See [Naming](#naming) for examples and [Rollout requirements](#rollout-requirements) for the required GitHub configuration.

## Deployments to Test

Deployments to the test server are automatically initiated when a pull request is landed to master. This means the test server will usually be up-to-date with the latest changes from the master branch. There are some situations however, when someone may want to manually push a deployment to the test server which can be accomplished with the following:

### Release Candidates

If a release candidate is created with a tag formatted as `vX.Y.Z-rcN` where X.Y.Z represents a version number and N is the release candidate number, a deployment of the tag's targeted ref will be deployed to the test server.

1. Go to https://github.com/Simon-Initiative/oli-torus/releases and click "Draft a new release"
1. Enter your vX.Y.X-rcN for **Tag version** and **Release Title**
1. Add the Features and Bug Fixes sections (formatted as markdown) to the description
1. Check "This is a pre-release"
1. Click "Publish release"

### `deploy-test` Tag

A deployment can be initiated by tagging any git ref with the `deploy-test` tag and pushing to remote. For example:

```
git tag --delete deploy-test   # if the tag previously existed locally
git tag deploy-test
git push origin deploy-test --force
```

## Deployments to Production

Deployments to the production server will be initiated when a release is created with the tag formatted as `vX.Y.Z` where X.Y.Z represents a version number.

> **Note:** Production deployments assume a previous build has been packaged, and therefore any commit tagged as a release must exist on the `master` branch, a `hotfix|prerelease-*` branch or be packaged by tagging the commit with the `package` tag first.

## Hotfixes

A hotfix branch can be created using the release tag you wish to branch from. For example:

```
git checkout -b hotfix-X.Y.[Z+1] vX.Y.Z
git push origin hotfix-X.Y.[Z+1]
```

Once the hotfix branch is created, it will essentially act as the master branch to land all bug fixes and enhancements that are intended to be included in the hotfix.

When a hotfix branch is ready to be deployed, it can be tagged using the **Release Candidate** and **Deployment Process** outlined above. Hotfix branches that follow the convention `hotfix-` will automatically be packaged when pushed to remote, just like master. Make sure to wait for the package step to complete before creating a release, or else the deployment will fail.

> **Note:** Because hotfix branches are automatically packaged based on the branch name convention, there is no need to manually tag with `package` before deploying.

Finally, make sure the hotfix branch is eventually merged back to `master` to be included in downstream development. Create a protected integration branch from the hotfix branch named `bug/MER-XXXX-back-merge-X.Y.Z`, using the parent Jira ticket key. Track any reconciliation work in child Sub-tasks. Downmerge `master` and resolve conflicts through a `sync/*` branch and PR targeting that integration branch, as described below. Once complete, open the integration PR against `master` and submit it to the merge queue after approvals and checks pass. The previous `integrate-X.Y.Z` naming convention is not accepted by **Validate master source branch**.

## Integration Branches

Every Jira Story, Bug, and Task has its own protected integration branch: `story/<issue-key>-<summary>`, `bug/<issue-key>-<summary>`, or `task/<issue-key>-<summary>`. Existing `integ-*` branches follow the same process. All integration branches ultimately target `master` through a PR and the merge queue.

All developer work is tracked in child Sub-tasks of the corresponding parent ticket. Each implementation branch starts from the parent's integration branch, and its PR targets that integration branch. This applies even to a small bug fix, chore, or ticket with only one implementation PR. An Epic may contain multiple parent tickets; it does not receive one shared integration branch.

Integration branch protections must require PRs, code review approvals, and status checks. Block direct pushes, including maintainer pushes that bypass review. Complete the entire parent ticket and its acceptance testing before opening the integration PR to `master`.

### Naming

Use the Jira issue type, issue key, and a short description for new integration branches:

| Pattern | Purpose | Example |
| --- | --- | --- |
| `story/*` | Story integration branch | `story/MER-1000-student-dashboard` |
| `bug/*` | Bug integration branch | `bug/MER-1002-fix-dashboard-loading` |
| `task/*` | Task integration branch for chores, DevOps, and other work | `task/MER-1003-update-build-tools` |
| `integ-*` | Existing integration branches; retained for compatibility | `integ-student-dashboard` |
| `dependabot/*` | Automated dependency updates allowed into `master` | `dependabot/npm_and_yarn/assets/example-1.2.3` |

Prefix matching is case-insensitive, so `Story/MER-1000-student-dashboard` also passes. Prefer lowercase prefixes for consistency. The workflow no longer imposes the old lowercase, hyphen-separated suffix restriction on `integ-*` branches.

Use `sub-task/*` for implementation branches and `sync/*` for downmerging `master` and resolving conflicts. Both target their parent integration branch and cannot merge directly into `master`. Sync work is also tracked in a child Sub-task; use its ticket key in the sync branch name. Dependabot branches remain an automated dependency-update exception to the developer Sub-task workflow.

### Jira Branch-name Preference

Each teammate can configure the branch name in Jira's suggested Git command from a ticket's **Development → Create branch** dropdown:

1. Open the branch-name format settings beside the Git create-and-checkout command.
2. Set the format to **Issue type / Issue key - Issue summary**.
3. Check the preview and select **Save**.

For a Story, this produces a name such as `story/MER-1000-student-dashboard`. A Task produces `task/*`; a Sub-task produces `sub-task/*`. The preference is [per user](https://support.atlassian.com/jira/kb/how-to-alter-the-branch-name-format-in-the-create-branch-option-in-development-panel/), so each teammate must save it.

This preference applies only to the suggested Git command. **Create branch in GitHub** does not use it and can still prefill the unprefixed `MER-...` name; Atlassian tracks this limitation in [JRACLOUD-86016](https://jira.atlassian.com/browse/JRACLOUD-86016). In that dialog, manually add the appropriate issue-type prefix or paste the branch name from the command suggestion without `git checkout -b`. Use `sync/` for a conflict-resolution branch even though its ticket is a Sub-task. Alternatively, run the suggested command locally and push the branch. Check that the source is `master` for a new integration branch, or the parent integration branch for a child implementation or sync branch.

### Creating an Integration Branch

Create the integration branch from `master` using the parent ticket's type and key. The ruleset must protect it from subsequent direct pushes as soon as it exists. Creating the branch establishes its starting point; all development changes arrive through Sub-task PRs.

```
git fetch origin
git switch -c story/MER-1000-student-dashboard origin/master
git push -u origin story/MER-1000-student-dashboard
```

The same steps apply to `bug/*` and `task/*`. Open the PR to `master` once the parent ticket's work is complete. Implementation PRs provide preview environments during development; the final integration PR provides a preview of the completed work.

### Working on Sub-tasks

Implement every child Sub-task on a separate branch based on its Story, Bug, or Task integration branch, following the usual title conventions:

```
git fetch origin
git switch -c sub-task/MER-1001-dashboard-skeleton origin/story/MER-1000-student-dashboard
# ...commit and push...
gh pr create --base story/MER-1000-student-dashboard --title "[FEATURE] [MER-1001] Dashboard skeleton"
```

Implementation PRs into an integration branch are reviewed and **squashed and merged** after required approvals and checks pass. Each PR gets its own preview environment. Sync PRs use merge commits instead, as described below.

When a PR depends on another PR that has not merged yet, branch from that PR's branch but still open the PR against the integration branch (its diff includes the other PR's commits until that one merges). Once the first PR is squashed and merged, rebase the dependent branch onto the integration branch:

```
git fetch origin
git rebase --onto origin/story/MER-1000-student-dashboard sub-task/MER-1001-dashboard-skeleton
git push --force-with-lease
```

### Keeping an Integration Branch in Sync with `master`

The `master` merge queue validates completed integration PRs against the latest `master` and any earlier queued changes. It does not continually update the integration branch itself. If conflicts arise, create a new `sync/*` branch from the integration branch and merge `master` into that sync branch. Use a child Sub-task to track conflict resolution; `MER-1004` below is that Sub-task's key.

```
git fetch origin
git switch -c sync/MER-1004-sync-master origin/story/MER-1000-student-dashboard
git merge --no-ff origin/master
# Resolve conflicts, stage the resolved files, and complete the merge commit.
git push -u origin sync/MER-1004-sync-master
gh pr create --base story/MER-1000-student-dashboard --head sync/MER-1004-sync-master --title "[CHORE] [MER-1004] Sync master into student dashboard"
```

Review the sync PR and run the same required checks as other PRs targeting the integration branch. Merge it using **Create a merge commit**, preserving the merge from `master`. Squashing or rebasing the sync PR discards that ancestry and can make later syncs repeat conflicts. Repository settings must allow merge commits, and integration branch rules must permit non-linear history for this process.

After the sync PR merges, obtain any renewed approvals and passing checks on the integration PR, then submit it to the `master` merge queue again. Never push the resolved changes directly to the integration branch or `master`.

### CI for Integration Branches

All integration branches require PRs, review approvals, and passing status checks, including `Elixir build and test` and `TypeScript build and test`. Direct pushes and force pushes are blocked; deletion remains restricted until the integration PR has merged. Configure the additional prefixes before relying on these protections. These requirements apply to both implementation and sync PRs.

The existing CI configuration below still uses `integ-*` for integration branch triggers. Accepting `story/*`, `bug/*`, and `task/*` as sources for `master` does not automatically enable checks when those branches are used as PR targets.

| Event | What runs |
| --- | --- |
| PR into `integ-*` | Build and tests, PR Playwright suite, PR title validation, Danger, AI review, and a preview environment |
| Push to `integ-*` (every merge into it) | Build and tests and the PR Playwright suite, to verify the combined result of the merged PRs |
| Completed integration PR from `integ-*` into `master` | Build and tests, PR Playwright suite, PR title validation, source branch validation, and a preview environment. Danger and AI review are skipped because every change on the branch already went through them in its own PR |

PRs from the new prefixes into `master` receive the normal master PR checks, including **Validate master source branch**. The existing Danger and AI review skip conditions apply only to `integ-*` sources.

Every required check for `master` must also report on the merge queue's `merge_group` event. Build and Playwright already have that trigger. The new source-branch validator currently handles only `pull_request`, so merge-queue support is a rollout prerequisite. Queue refs are generated by GitHub and must not be mistaken for the original PR's source branch. See [GitHub's merge queue CI requirements](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-a-merge-queue#configuring-continuous-integration-ci-workflows-for-merge-queues).

### Rollout Requirements

The workflow file alone does not configure GitHub rulesets or personal Jira preferences. Complete the following rollout work tracked in [MER-6050](https://eliterate.atlassian.net/browse/MER-6050):

1. Extend the integration branch ruleset targets to cover `integ-*`, `story/*`, `bug/*`, and `task/*`, including case variants. Require PRs, review approvals, and status checks, and block direct pushes, including bypass pushes. Retain force-push and deletion restrictions. Allow merge commits for reviewed sync PRs; integration branches cannot require linear history. See `guides/process/pull-request-approvals.md` for targeting details.
2. Before using the new prefixes as integration PR targets, update the branch filters in `.github/workflows/build.yml`, `.github/workflows/pr-playwright.yml`, and `.github/workflows/validate_pr_title.yml` to cover them, including case variants. Verify PR checks and post-merge checks on those branches.
3. Make all required master checks report on `merge_group`, including **Validate master source branch**, and verify a queued integration PR can complete. The validator must still enforce allowed source names on PRs and handle queue events separately. After verification, require this check and the merge queue in the ruleset targeting only `master`. Remove any required check that refers to the deleted integration-name validator.
4. Notify the team that all Story, Bug, and Task work uses child Sub-task PRs into protected integration branches, followed by a completed integration PR through the master merge queue. Explain the sync PR process and Jira preference steps above. The preference is per user and changes only the suggested Git command; the **Create branch in GitHub** dialog still needs its branch name corrected manually.

### Merging an Integration Branch to `master`

Once all child Sub-tasks have merged and the parent Story, Bug, or Task passes acceptance testing, open the integration PR against `master`, using the parent ticket in the title and description:

```
gh pr create --base master --head story/MER-1000-student-dashboard --title "[FEATURE] [MER-1000] Student dashboard"
```

After the required reviews and checks pass, use GitHub to add the PR to the `master` merge queue. The queue tests the combined result against current `master` and preceding queued PRs, then merges it using the configured queue merge method. This replaces the local maintainer merge-and-push process. If conflicts prevent merging, complete a sync PR into the integration branch and requeue the integration PR. Fix any other implementation failures through child Sub-task PRs as well.

After the queue merges the PR, delete the integration branch through the repository's permitted cleanup process.
