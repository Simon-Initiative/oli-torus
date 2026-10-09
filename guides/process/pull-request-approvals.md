# Development and QA approvals

GitHub enforces merge approval for `master`. Jira tracks the handoff to QA and
testing progress. Approval order is not enforced.

## GitHub ruleset

Configure an active repository branch ruleset for `master` with:

- One required approval from `Simon-Initiative/development`, matching all files (`*`).
- One required approval from the QA team, matching all files (`*`).
- Two required approvals overall, so two different people must approve.
- Stale approvals dismissed when new commits change the reviewed code.

Both teams must have repository write permission or higher. Configure the QA team
and its membership before enabling the rule. Prefer separate Development and QA
membership so each approval has a clear purpose. Review ruleset bypass permissions
explicitly; do not silently copy the existing branch protection review exemptions.
Keep the existing Elixir and TypeScript required checks and branch protections.

Use the ruleset's required-team reviewers. Listing both teams together in
`CODEOWNERS` permits approval from either owner and does not require both teams.

QA records its sign-off with an approving GitHub PR review. QA can use Request
changes to block a previously approved PR again. Changing the Jira ticket status
alone does not grant or revoke merge approval.

## Jira handoff

`.github/workflows/jira-move-ticket-qa.yml` handles submitted approvals for open,
non-draft PRs from this repository. It loads its helper from the immutable PR base
commit and checks the review author's active Development team membership. Team
maintainers and inherited members qualify. QA-only reviewers do not trigger Jira.
A reviewer belonging to both teams qualifies because they belong to Development.

The lookup first verifies that the team is accessible, then reads the review
author's membership. Non-members and pending members are skipped. Lookup failures
fail the workflow and prevent the Jira webhook. The helper never runs PR code.

Configure these repository secrets before rolling out the workflow:

| Secret                    | Purpose                                                                                                                                                                                                        |
| ------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `TEAM_MEMBERS_READ_TOKEN` | Fine-grained PAT owned by an organization member, with Simon-Initiative as resource owner and organization **Members: read** permission. Follow the organization's approval policy and token rotation process. |
| `JIRA_WEBHOOK_URL`        | Existing incoming Jira automation webhook URL.                                                                                                                                                                 |
| `JIRA_WEBHOOK_SECRET`     | Existing webhook authentication token.                                                                                                                                                                         |

The workflow's ordinary `GITHUB_TOKEN` is used only to read the trusted helper.
It does not provide the organization membership permission. If a GitHub App is
used instead of a PAT later, mint its installation token during each workflow run;
do not store an expiring installation token as a permanent secret.

Keep the existing Jira automation's mapping from the PR title's ticket reference
to the Jira issue. Its transition to QA must be conditional: skip tickets already
in QA or Done. This makes repeated developer approvals and workflow reruns harmless.
QA-only approval must not change Jira status. Other completion transitions remain
outside this workflow.

Disable any `jira-status-changed` outbound Jira automation once this replacement is
active. This design does not use a `jira/qa-complete` status, Jira polling, or a
Jira-to-GitHub status receiver.

## Verification and rollout

Run the local membership tests from the repository root:

```sh
node --test .github/scripts/development-review.test.cjs
```

Configure the membership credential and QA team, then merge the workflow/helper
before expecting the new handoff to run: the helper is deliberately read from the
PR's base commit. Enable the ruleset and verify the following with test PRs and a
test Jira ticket:

1. A Development approval sends the existing webhook and moves the ticket to QA.
2. A QA-only approval sends no Jira webhook.
3. A repeated developer approval leaves tickets already in QA or Done unchanged.
4. Only Development approval, only QA approval, or two approvals from one team
   cannot satisfy both team requirements.
5. Both teams approving and all required checks passing allow merging.
6. New code changes dismiss stale approvals and block merging until reapproval.
7. Missing or invalid membership credentials fail the handoff without calling Jira.

Also confirm the intended behavior for any accounts allowed to bypass rules.
These live checks require the GitHub settings, credential, and Jira automation;
the local tests cover membership decisions and API failures only.

## References

- [GitHub ruleset required reviewers](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets#required-reviewers)
- [GitHub team membership lookup](https://docs.github.com/en/rest/teams/members#get-team-membership-for-a-user)
