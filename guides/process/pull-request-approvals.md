# Development and QA approvals

GitHub rulesets must enforce two approval stages: developer code review for PRs into
integration branches, then QA approval for the completed integration PR to `master`.
Jira tracks testing progress separately; the review-event automation described below
does not replace GitHub's merge requirements.

## GitHub rulesets

Configure required reviewers by target branch:

| Target branches | Required reviewer | Required approval count |
| --- | --- | --- |
| Integration branches matching `integ-*`, `story/*`, `bug/*`, and `task/*` | `Simon-Initiative/torus-dev` (Development), matching all files (`*`) | One |
| `master` | `Simon-Initiative/torus-qa` (QA), matching all files (`*`) | One |

The integration ruleset covers both implementation and sync PRs. The master ruleset
requires QA approval of the integrated result. Do not apply both team requirements
to both destinations through overlapping rulesets.

Both rulesets must require:

- Stale approvals dismissed when new commits change the reviewed code.
- Pull requests for all changes, including syncs from `master`; direct pushes blocked.
- Existing required status checks, including Elixir and TypeScript build and test.

Every Story, Bug, and Task uses implementation PRs targeting its integration
branch, referencing the main ticket or optional child Sub-tasks. The completed
integration branch opens a PR to `master` and
enters its merge queue after QA approval and required checks pass. Conflict
resolution uses a `sync/*` branch based on the integration branch and a reviewed PR back into it.
All PRs into integration branches, including implementation and sync PRs, must use
**Create a merge commit**. Enable merge commits in repository settings and require
this method for integration branches while allowing non-linear history.

Use the appropriate child team as the required reviewer for each target. The
parent `Simon-Initiative/torus` team does not distinguish Development from QA.

Both teams must have repository write permission or higher. Configure the QA team
and its membership before enabling the rule. Prefer separate Development and QA
membership so each approval has a clear purpose. Remove bypass permissions that
would allow developers or maintainers to push changes directly to integration
branches or `master`; syncs and final integration merges must follow the PR process.
Keep the existing Elixir and TypeScript required checks and branch protections.

Match prefix case variants explicitly in the integration ruleset, for example
`[sS][tT][oO][rR][yY]/**/*` for Story branches. Apply the same character-set approach
to `bug`, `task`, and `integ`. GitHub ruleset `*` does not cross `/`, so use `**/*`
when a suffix can contain nested paths. Retain a pattern for flat legacy
`integ-*` names as well. See [GitHub's ruleset pattern syntax](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/creating-rulesets-for-a-repository#using-fnmatch-syntax).

In the ruleset targeting **only `master`**, also require **Validate master source
branch** and the merge queue after verifying the required checks on both PR and
queue events. This check accepts `integ-*`, `story/*`,
`bug/*`, `task/*`, and `dependabot/*` sources case-insensitively. Do not add this
requirement to the integration branch ruleset: the source-branch policy applies to PRs targeting `master`. The current workflow still
needs `merge_group` support before it can be required with the merge queue.
All required master checks must report on queue events; do not validate GitHub's
temporary queue ref as though it were the PR's source branch. Remove any requirement
for the deleted integration-name validator. Complete the CI filter updates, queue
support, and team notification in `guides/process/development.md` under **Rollout
Requirements** before relying on the new process.

Use each ruleset's required-team reviewer. Listing both teams together in
`CODEOWNERS` permits approval from either owner and does not enforce the reviewer
required for each target branch.

QA records its sign-off with an approving GitHub PR review. QA can use Request
changes to block a previously approved PR again. Changing the Jira ticket status
alone does not grant or revoke merge approval.

## Jira transitions

`.github/workflows/jira-pr-approval.yml` handles submitted approvals for open
PRs from this repository, including drafts, regardless of the target branch.
It loads its helper from the immutable PR base commit and checks the review
author's active membership in `torus-dev` (Development), then `torus-qa` (QA).
Membership in the parent `torus` team alone does not qualify. Team maintainers and
inherited members qualify. Development takes precedence for reviewers in both
teams; their approval requests only the Development transition. A QA-only reviewer
must submit the QA approval for the automated completion transition.

Each lookup first verifies that the team is accessible, then reads the review
author's membership. Reviewers with no active membership in either team are
skipped. Lookup failures fail the workflow and prevent the Jira webhook; a failed
Development lookup never falls back to QA. The helper never runs PR code.

The webhook retains the original GitHub review event and adds one verified field:

```json
{ "approval_team": "torus-dev" }
```

The webhook uses the exact GitHub team slug: `torus-dev` or `torus-qa`.
Existing `pull_request` and `review` fields
remain available to Jira, including the PR title and review author. The workflow
does not fetch earlier reviews or replay an early QA approval after Development
approves.

Configure these repository secrets before rolling out the workflow:

| Secret                    | Purpose                                                                                                                                                                                                        |
| ------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `TEAM_MEMBERS_READ_TOKEN` | Fine-grained PAT owned by an organization member, with Simon-Initiative as resource owner and organization **Members: read** permission. Follow the organization's approval policy and token rotation process. |
| `JIRA_WEBHOOK_URL`        | Incoming Jira automation webhook URL for both approval transitions.                                                                                                                                            |
| `JIRA_WEBHOOK_SECRET`     | Existing webhook authentication token.                                                                                                                                                                         |

The workflow's ordinary `GITHUB_TOKEN` is used only to read the trusted helper.
It does not provide the organization membership permission. If a GitHub App is
used instead of a PAT later, mint its installation token during each workflow run;
do not store an expiring installation token as a permanent secret.

### Incoming Jira automation

Keep the existing webhook authentication and mapping from the PR title's ticket
reference to the Jira issue. Replace the unconditional transition with an
if/else-if block using these exact conditions:

| `{{webhookData.approval_team}}`                 | Current Jira status | Action               |
| ----------------------------------------------- | ------------------- | -------------------- |
| `torus-dev`                                     | `PR`                | Transition to `QA`   |
| `torus-qa`                                      | `QA`                | Transition to `Done` |
| Any other combination, including a missing team | Any                 | No transition        |

Use an Issue fields condition on Status for each branch, plus a smart-value
comparison for `{{webhookData.approval_team}}`. Ensure the rule actor can perform
both Jira workflow transitions. Remove the previous transition action outside
this conditional block; otherwise a QA notification could still move a ticket
back to QA. Do not add an action that automatically advances from QA to Done
after a Development notification.

Repeated approvals leave QA and Done tickets unchanged unless they represent the
next eligible team approval. A QA approval received while the ticket is still in
PR is ignored; QA must submit another approval after the ticket reaches QA.
Rerunning an old workflow resends the old review event and must not be used in
place of a new approval. These conditions are evaluated when Jira processes the
notification, not against a stored history of approvals.

Done represents QA sign-off and may precede the PR merge. Review dismissals,
requested changes, and new commits do not automatically move Jira backward;
GitHub still enforces its own review and CI requirements.

Disable any `jira-status-changed` outbound Jira automation once this replacement is
active. This design does not use a `jira/qa-complete` status, Jira polling, or a
Jira-to-GitHub status receiver.

## Verification and rollout

Run the local membership tests from the repository root:

```sh
node --test .github/scripts/review-approval.test.cjs
```

Configure the membership credential and QA team, and update the incoming Jira
automation to use the conditional block above **before enabling this workflow**.
The old unconditional QA action cannot safely receive QA-team notifications.
Then merge the renamed workflow/helper into the target branches before expecting
the transitions to run there: the helper is deliberately read from the PR's base
commit. Enable the destination-specific approval rulesets, and verify the following
with test PRs and a test Jira ticket:

1. A Development approval sends `approval_team: torus-dev` and moves a PR-status ticket to QA
   for both draft and ready-for-review PRs, regardless of the target branch.
   Draft PRs remain unmergeable until marked ready for review.
2. A QA-only approval sends `approval_team: torus-qa` and moves a QA-status ticket to Done.
3. An early QA approval leaves a PR-status ticket unchanged. Development approval
   then moves it to QA; a newly submitted QA approval moves it to Done.
4. Repeated Development approvals leave QA and Done tickets unchanged; repeated
   QA approvals leave Done tickets unchanged. Other statuses and missing or
   unrecognized `approval_team` values cause no transition.
5. A reviewer in both teams requests only PR to QA, even on a workflow rerun.
6. QA approval alone cannot satisfy the Development requirement on an integration
   branch; Development approval alone cannot satisfy the QA requirement on `master`.
7. Development approval and passing required checks allow an implementation or sync
   PR into an integration branch. QA approval and passing required checks allow a
   completed integration PR to enter the master merge queue.
8. New code changes dismiss stale approvals and block merging until reapproval.
9. Missing or invalid membership credentials fail the workflow without calling Jira.

Also confirm that direct pushes to integration branches and `master` are rejected,
that implementation and sync PRs use merge commits and preserve ancestry, and that a completed
integration PR can pass the required merge-group checks and merge through the queue.
These live checks require the GitHub settings, credential, and Jira automation;
the local tests cover approval-team classification and API failures only.

Workflow test

## References

- [GitHub ruleset required reviewers](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets#required-reviewers)
- [GitHub team membership lookup](https://docs.github.com/en/rest/teams/members#get-team-membership-for-a-user)
