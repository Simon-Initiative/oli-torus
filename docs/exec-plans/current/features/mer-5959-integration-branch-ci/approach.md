# MER-5959 GitHub CI/CD Support for Feature Integration Branches

Jira: <https://eliterate.atlassian.net/browse/MER-5959>

## Purpose

Multi-PR features that must not land incrementally on `master` will be developed on
long-lived `integ-<feature-name>` branches (for example `integ-student-dashboard`).
Individual PRs target the integration branch; when the feature is complete, the
integration branch is opened as a PR against `master`.

PRs whose base is an `integ-*` branch must run the same checks and steps that PRs
against `master` run.

## Current State

| Workflow                                                            | Trigger today                                                               | Runs for an `integ-*` base?                          |
| ------------------------------------------------------------------- | --------------------------------------------------------------------------- | ---------------------------------------------------- |
| `build.yml` (Elixir build/test, TypeScript build/test, auto-format) | `pull_request` to `master`, `hotfix-*`, `prerelease-*`, `nextgen-ux`        | No                                                   |
| `pr-playwright.yml` (`@pr` Playwright suite)                        | same branch list                                                            | No                                                   |
| `validate_pr_title.yml`                                             | `pull_request` to `master`, `hotfix-*`, `prerelease-*`                      | No                                                   |
| `ai-review.yml`, `danger.yml`, `build-preview-image.yml`            | every `pull_request`, no branch filter                                      | Yes                                                  |
| `package.yml`                                                       | push to `master`, `hotfix-*`, `prerelease-*`, `nextgen-ux`; manual dispatch | Not needed (manual dispatch covers ad hoc packaging) |

`master`, `hotfix-*`, and `prerelease-*` use classic branch protection with the
required checks `Elixir build and test` and `TypeScript build and test`. The
repository allows squash merges only.

## Decision Summary

### Explicit `integ-*` branch pattern

GitHub does not allow variables or expressions in `on.<event>.branches`, so the
pattern is added explicitly to each workflow. Centralizing the branch list or
dropping the branch filter is out of scope.

The glob `integ-*` does not match the existing hotfix back-merge convention
`integrate-X.Y.Z`.

### Post-merge verification on integration branches

Two PRs can pass independently and still break once combined. `build.yml` and
`pr-playwright.yml` also run on `push` to `integ-*` (each squash merge into the
integration branch is a push). This also stores an Actions cache scoped to the
integration branch, which PRs targeting it can restore.

`build.yml`'s `auto-format` job commits to the PR head branch and is only
meaningful for pull requests, so it and the `check-simon-token` job it depends on
are restricted to `pull_request` events. Because pushes run with the repository's
default token permissions, `build.yml` now declares `permissions: contents: read`;
no job writes through `GITHUB_TOKEN` (auto-format pushes with the simon-bot token).

### Skip Danger and AI review on the final `integ-*` → `master` PR

Every change on an integration branch already went through its own PR, where
Danger and AI review ran. Re-running them on the accumulated diff only produces
size warnings and duplicated, expensive reviews. Both workflows are skipped when
`head_ref` starts with `integ-`, `base_ref` is `master`, and the head branch belongs
to this repository (a fork contributor chooses the branch name, so fork PRs never
skip). Build, Playwright, and title validation still run.

### Integration branch naming validation

A lightweight workflow without branch filters fails when a branch looks like an
integration branch but does not follow `integ-[a-z0-9]+(-[a-z0-9]+)*`, because
such a branch silently misses the CI configured for `integ-*`:

- on `pull_request`, it validates the PR base branch, filtered with the
  case-insensitive branch pattern `[iI][nN][tT][eE][gG]**` so unrelated PRs do not
  start a runner;
- on `create`, it validates the newly created branch.

A name "looks like" an integration branch when it starts with `integ`
(case-insensitive). Names starting with `integrate-` are excluded because they
belong to the hotfix back-merge convention.

### Documented developer workflow

`guides/process/deployment.md` gains a "Feature Integration Branches" section:
when to use one, naming, creating the branch together with a long-lived draft PR
to `master` (which provides a continuously updated preview of the integration
branch), PRs into the branch (squash), syncing with `master`, CI behavior, and
the pros and cons of the two strategies for the final merge to `master`.

## Out of Scope

- `nextgen-ux` references in any workflow.
- The dead `Clean on master` step in `build.yml`.
- Centralizing or removing workflow branch filters.
- Branch-based preview environments outside the PR flow (Argo CD changes).
- Stacked pull requests.
- Workflow `concurrency` groups.
- Repository settings: branch protection for `integ-*` is configured by a
  repository admin (see Phase 8).

## Implementation Plan

### Phase 1: PR checks for `integ-*` bases

- [x] Add `integ-*` to `on.pull_request.branches` in `build.yml`,
      `pr-playwright.yml`, and `validate_pr_title.yml`.

### Phase 2: Post-merge verification on `integ-*`

- [x] Add `on.push.branches: [integ-*]` to `build.yml` and `pr-playwright.yml`,
      with a short comment explaining why.
- [x] Restrict `build.yml`'s `auto-format` job to `pull_request` events.
- [x] Make `ts-build-test` checkout fall back to the pushed ref when there is no
      pull request payload.
- [x] Update the `pr-playwright.yml` header comment to mention the push trigger.

### Phase 3: Skip Danger and AI review on the final merge PR

- [x] Add the `integ-*` → `master` skip condition, with a short comment, to the
      `changes` job in `ai-review.yml` (the `specialist` job depends on it).
- [x] Add the same condition, with a short comment, to the job in `danger.yml`.

### Phase 4: Integration branch naming validation

- [x] Add `.github/workflows/validate_integration_branch.yml` with the
      `pull_request` (base branch) and `create` (new branch) checks.

### Phase 5: Documentation

- [x] Add the "Feature Integration Branches" section to
      `guides/process/deployment.md`.
- [x] Note in `guides/process/changelog-pr.md` that feature work may branch off
      an `integ-*` branch instead of `master`.

### Phase 6: Agent skills

- [x] Repository skill `.agents/skills/change-cleanup/SKILL.md`: detect the base
      branch (PR metadata first, then the closest of `origin/master` and
      `origin/integ-*` by merge-base, asking when ambiguous) instead of defaulting to
      `master`.
- [x] Local, uncommitted skills under `~/.codex/skills/` (`open-draft-pr`,
      `pr-review-guide`, `pr-review-guide-2`, `pr-review-companion`): same base-branch
      detection. `pr-review-companion` needed no change: it always reads the base
      from PR metadata and never assumes `master`.

### Review round

- [x] Security and performance reviews (`.review/security.md`,
      `.review/performance.md`). Applied: fork guard on the Danger and AI review
      skip, `permissions: contents: read` in `build.yml`, `check-simon-token`
      restricted to pull requests, and a base-branch filter on the naming
      validation. Accepted: the one-time run when an integration branch is
      created.

### Phase 7: Verification and rollout (requires explicit approval)

- [x] Lint all changed workflows with `actionlint` (release binary; Docker was
      unavailable). No new findings; the only findings are pre-existing outdated
      action versions also reported on `master`.
- [x] Verify the naming rule against a table of valid and invalid names (20 cases,
      all matching expectations).
- [x] Smoke test on GitHub with a disposable `integ-ci-smoke` branch, created from a
      temporary commit of the working tree so the ticket branch itself stays
      uncommitted (PRs #6876, #6877, #6878). Results:
  - pushing `integ-ci-smoke` ran Build & Test (Elixir and TypeScript jobs;
    `check-simon-token` and `auto-format` skipped) and the Playwright suite, all
    green, and the naming validation passed on branch creation;
  - the draft PR #6876 `integ-ci-smoke` → `master` ran Build & Test, Playwright,
    title validation, and the preview image build, all green, and skipped Danger
    and AI review;
  - the child PR #6877 into `integ-ci-smoke` ran the same six workflows as a
    regular PR into `master` (Build & Test, Playwright, title validation, Danger,
    AI review, preview) plus the naming validation, all green;
  - squash merging #6877 triggered the push runs on `integ-ci-smoke` and re-ran
    the draft PR checks, all green, with Danger and AI review still skipped;
  - creating `integ_ci_smoke` and PR #6878 against it both failed the naming
    validation, and Build & Test, Playwright, and title validation did not run
    for that base;
  - previews for #6876 (draft, base `master`) and #6878 (base other than
    `master`) answered 401, deployed behind auth. They initially stayed at 404
    because of an unrelated preview infrastructure problem that DevOps fixed.
  - Observations: two PRs sharing one head commit show each other's check runs,
    since checks attach to commits; title and naming validation only run on
    opened, edited, and reopened events, so they do not appear on later commits
    of a PR.
- [x] Close the smoke PRs without merging and delete every disposable branch.

### Phase 8: Pull request and admin handoff

- [ ] Open the ticket PR with an "Admin configuration required" section in its
      description, so the repository settings this work depends on are applied
      by an admin before any integration branch is relied on. The section contains:

  > **Admin configuration required**
  >
  > The new CI only blocks merges into integration branches once they are
  > protected. In **Settings → Branches → Add branch protection rule**, create a
  > rule for the branch name pattern `integ-*`, mirroring the existing `hotfix-*`
  > rule:
  >
  > 1. **Require a pull request before merging**, with the same required approvals
  >    as `hotfix-*`.
  > 2. **Require status checks to pass before merging**, with the required checks
  >    `Elixir build and test` and `TypeScript build and test` (and "require
  >    branches to be up to date" only if `hotfix-*` requires it).
  > 3. Leave **Allow force pushes** and **Allow deletions** unchecked. Deleting an
  >    integration branch after its final merge is then done by an admin.
  > 4. Under **Allow specified actors to bypass required pull requests**, add the
  >    maintainers who sync integration branches with `master`. The repository
  >    allows squash merges only, and a sync must be a real merge commit pushed
  >    directly (see "Keeping an Integration Branch in Sync with `master`" in
  >    `guides/process/deployment.md`). Do not add the simon-bot account.
  >
  > To verify, create any `integ-*` branch and check that
  > `gh api repos/Simon-Initiative/oli-torus/branches/<branch> --jq '.protected, .protection.required_status_checks.contexts'`
  > returns `true` and both check names.
- [ ] Confirm with the admin that the rule is in place before the first real
      integration branch is created.

## Risks and Assumptions

- Without branch protection on `integ-*`, the new checks run but do not block
  merges, and anyone with write access could push unreviewed code that the final
  PR would then carry to `master` without Danger or AI review. The protection
  handoff is a prerequisite for relying on that skip.
- The repository allows squash merges only. Syncing `master` into an integration
  branch must be a real merge commit pushed by someone on the bypass list;
  squashing a sync PR loses the merge base and repeats conflicts on every sync.
- With the draft PR convention, each merge into an integration branch runs build
  and Playwright twice (push run and draft PR `synchronize`). This cost is
  accepted; the push run guarantees verification even without a draft PR.
- Skipping Danger and AI review on the final PR assumes every change reached the
  integration branch through a reviewed PR. Conflict resolutions in `master` sync
  merges are not AI-reviewed.
- Previews are generated by the `oli-torus-pr-previews` ApplicationSet in
  `Simon-Initiative/oli-torus-gitops` (`argocd/appsets/oli-torus-deployments.yaml`).
  Its `pullRequest` generator has no label or branch filters, so every open PR
  gets a preview regardless of base branch or draft state. Open draft PRs were
  confirmed to have live previews (HTTP 401 behind the shared oauth2-proxy,
  versus 404 for a nonexistent preview). A change to that generator in the GitOps
  repository would silently break the draft PR preview convention.
- The `create` event cannot prevent a badly named branch from being created; it
  only reports a failed run.
- Creating an integration branch is itself a push to `integ-*`, so it runs one
  full build and Playwright pass on code that is effectively `master`. This
  one-time cost per branch is accepted.

## Verification Strategy

These changes are GitHub Actions configuration and documentation, so there is no
ExUnit or Jest coverage to add. Verification is `actionlint`, a local table test
of the naming rule, and the GitHub smoke test in Phase 7.
