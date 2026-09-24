# CI/CD and Deployment Process

## Overview

Torus uses Github Actions for its CI/CD pipelines. When a PR is opened, a build is automatically started and several checks are run including unit tests and lint checks which must all pass before a PR can be merged. Once a branch is merged into master, the resulting commit is packaged and deployed to the test server ([tokamak.oli.cmu.edu](https://tokamak.oli.cmu.edu)). The test server will always represent the latest from master unless a manual deployment is made. When a release is made (tagged vX.Y.Z), a deployment is kicked off to the production server ([proton.oli.cmu.edu](proton.oli.cmu.edu)). A production deployment will always use a prebuilt artifact identified by the version and commit SHA to ensure that the release tested is the same as the release deployed.

**Test Server:** [tokamak.oli.cmu.edu](tokamak.oli.cmu.edu)

**Production Server:** [proton.oli.cmu.edu](proton.oli.cmu.edu)

## Pull Requests

Every pull request is required to pass a set of status checks in both Elixir and Typescript including a successful build, all unit tests passing, and successful lint with no errors (TypeScript). These checks are automatically started when a pull request is created. Other automated checks include Coveralls for unit test coverage and GitGuardian for identifying accidentally leaked secrets, however these checks are only informative and discretion is left to the developer and code reviewer to decide if issues found are blocking.

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

Finally, make sure the hotfix branch is eventually merged back to master to be included in downstream development. To do this easily, create a new branch from the hotfix branch called `integrate-X.Y.Z` (the name here is not necessarily important, but just serves as an example). Then pull `master` into this integration branch. Once any/all merge conflicts are resolved, open a PR against master.

## Feature Integration Branches

When a feature or epic spans multiple PRs that should not land incrementally on `master`, develop it on a long-lived feature integration branch named `integ-<feature-name>`. Individual PRs target the integration branch, and the integration branch is merged to `master` once the feature is complete. Features delivered in a single PR keep targeting `master` directly.

### Naming

Integration branch names must follow `integ-<name>`, where `<name>` is lowercase letters and digits separated by single hyphens, for example `integ-student-dashboard` or `integ-genai-authoring`. CI for integration branches is configured through the `integ-*` branch pattern, so a differently named branch silently misses it. The **Validate Integration Branch Name** workflow fails for branches (and PRs based on branches) whose name starts with `integ` but does not follow the convention. Branches starting with `integrate-` belong to the hotfix back-merge process above and are not checked.

### Creating an Integration Branch

Create the branch from `master` and immediately open a draft PR from it against `master`, titled with the epic's ticket. GitHub cannot open a PR between identical branches, so the branch starts with an empty commit:

```
git fetch origin
git switch -c integ-student-dashboard origin/master
git commit --allow-empty -m "Start integ-student-dashboard"
git push -u origin integ-student-dashboard
gh pr create --draft --base master --head integ-student-dashboard --title "[FEATURE] [MER-XXXX] Student dashboard"
```

Keep this PR in draft until the feature is complete. Every PR gets a preview environment at `https://preview-<PR number>.plasma.oli.cmu.edu/`, so this draft PR provides a preview of the integration branch that is rebuilt on every merge into it. It also runs the PR checks against the integration branch merged with `master`, which surfaces incompatibilities with `master` early.

### Working on the Feature

Each unit of work is a normal PR whose base is the integration branch, following the usual title conventions:

```
git fetch origin
git switch -c MER-1001-dashboard-skeleton origin/integ-student-dashboard
# ...commit and push...
gh pr create --base integ-student-dashboard --title "[FEATURE] [MER-1001] Dashboard skeleton"
```

PRs into an integration branch are reviewed and **squashed and merged**, exactly like PRs into `master`, and each one gets its own preview environment.

When a PR depends on another PR that has not merged yet, branch from that PR's branch but still open the PR against the integration branch (its diff includes the other PR's commits until that one merges). Once the first PR is squashed and merged, rebase the dependent branch onto the integration branch:

```
git fetch origin
git rebase --onto origin/integ-student-dashboard MER-1001-dashboard-skeleton
git push --force-with-lease
```

### Keeping an Integration Branch in Sync with `master`

Merge `master` into the integration branch regularly so conflicts are resolved in small steps rather than at the end:

```
git fetch origin
git switch integ-student-dashboard
git pull
git merge origin/master
git push origin integ-student-dashboard
```

This must be a real merge commit. Squashing a sync PR loses the merge base, so every later sync repeats the same conflicts. Because integration branches only accept changes through PRs, this push is done by a maintainer allowed to bypass the branch protection.

### CI for Integration Branches

Integration branches are protected like hotfix branches: changes arrive through PRs that must pass the `Elixir build and test` and `TypeScript build and test` checks, and force pushes and deletion are blocked.

| Event | What runs |
| --- | --- |
| PR into `integ-*` | Everything a PR into `master` runs: build and tests, PR Playwright suite, PR title validation, Danger, AI review, and a preview environment |
| Push to `integ-*` (every merge into it) | Build and tests and the PR Playwright suite, to verify the combined result of the merged PRs |
| PR from `integ-*` into `master` (the draft PR) | Build and tests, PR Playwright suite, PR title validation, and a preview environment. Danger and AI review are skipped because every change on the branch already went through them in its own PR |

### Merging an Integration Branch to `master`

When the feature is complete, mark the draft PR as ready for review, bring the branch up to date with `master`, and merge it once it is approved and its checks pass. There are two ways to land it:

**Squash and merge through the PR.**

- Pros: it is the standard flow the repository is configured for, it needs no special permissions, and the whole feature can be reverted as a single commit.
- Cons: `master` gets one large commit for the whole feature, so the individual PRs and their ticket references disappear from its history, and `git blame` and `git bisect` lose their granularity. The integration branch must not be reused afterwards, because its history no longer shares a merge base with `master`.

**Merge commit pushed by a maintainer** (as done for recent hotfix back-merges, for example `integrate-v0.34.2`). After the PR is approved and green, a maintainer allowed to bypass branch protection merges it locally and pushes, and GitHub marks the PR as merged:

```
git fetch origin
git switch master
git pull
git merge --no-ff origin/integ-student-dashboard
git push origin master
```

- Pros: every squashed PR from the integration branch lands on `master` with its own commit and ticket reference, so history, `git blame`, and `git bisect` stay granular, and the whole feature can still be reverted with `git revert -m 1 <merge commit>`.
- Cons: it bypasses the merge button and the repository's squash-only setting, requires a maintainer with bypass permissions, and makes `master` history non-linear.

After the merge, delete the integration branch.
