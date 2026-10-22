---
name: integration_branch_workflow
description: Set up or sync Jira MER integration branches in Simon-Initiative/oli-torus. Use for "let's begin work on MER-1234", "Create an integration branch for MER-1234", "Set up branches for MER-1234", "sync MER-1234 integration branch", "update my integration branch for MER-1234 with the latest", or "pull the latest from master into my integration branch", including Jira URLs. Set up parent and child branches, or merge master through a sync branch with automatic/manual conflict resolution and a PR to the integration branch. Do not use outside oli-torus, for epics, or for read-only ticket lookups.
---

# Integration Branch Workflow

Support two operations:

- **Start work:** Prepare the integration branch and one sub-task work branch, ending on the selected work branch. Follow the setup workflow below; setup alone does not implement the ticket, push branches, or open PRs.
- **Sync with master:** Follow [Sync an integration branch](references/sync.md) to merge the latest master into a separate sync branch, resolve conflicts with the engineer's chosen mode, and open or reuse a PR targeting the integration branch. Do not run the start-work sub-task selection or create an implementation branch for a sync request.

Follow [Integration Branches](guides/process/development.md#integration-branches) in the verified oli-torus checkout. Resolve this repository-relative link from the checkout root, not the skill directory. Read that section and its subsections during setup; it defines the branch ancestry, PR destinations, protections, and completion process. If it cannot be read, report the missing guidance before creating branches.

## Jira CLI availability

These rules apply to both setup and sync. Jira automation requires the installed `jira` CLI to be configured and authenticated. Before the first Jira operation, check `command -v jira`, then use the first required read (such as `jira issue view <KEY> --plain`) to establish access. Do not inspect or print credentials.

If the CLI is missing, unconfigured, unauthenticated, or cannot access the required issue, skip the affected Jira step and continue independent Git/GitHub work with the information available. Tell the engineer what failed and which Jira actions they must complete manually. Do not switch to browser automation or direct REST, repeatedly retry unavailable Jira operations, or require installation before continuing unrelated work. Suggest installing [Jira CLI](https://github.com/ankitpokhrel/jira-cli) when missing, or configuring/authenticating it when already installed. Do not install it or change credentials automatically.

All Jira reads and writes below are conditional on that access. When a step is skipped:

- Use ticket details supplied by the engineer and established branch/PR context; label Jira details that could not be verified. Never invent ticket keys, summaries, parent relationships, types, or statuses. Ask only for missing information needed for the next dependent action, such as a new integration ticket's type and summary or the selected child ticket's key.
- A failed sub-task lookup does not mean no sub-tasks exist. Ask the engineer to check the parent in Jira and identify the appropriate child. If a child must be created manually, provide its proposed parent, type, summary, and description from the known scope. Continue the integration branch work, but defer a child implementation branch until its real ticket key is available.
- For skipped status changes, instruct the engineer to move the parent and selected child from `Analyzing` or `To Do` to `In Progress` if applicable. If the current status could not be read, make that instruction conditional; do not claim the status was changed.
- If a write may have succeeded before access failed, tell the engineer to inspect Jira for the result before repeating it manually. Do not report an unverified write as completed or create duplicate tickets.
- In the final handoff, list the specific manual Jira actions and known ticket links alongside the completed Git/GitHub work. Syncs use the parent ticket directly and require no child-ticket creation or status changes; report any parent details that could not be verified.

If access becomes available later, resume only outstanding Jira operations under the normal approval and read-back rules.

## Start-work setup

### Confirm scope and inspect

1. Before querying Jira or changing Git state, verify the current checkout or worktree with `git rev-parse --show-toplevel` and `git remote -v`. A remote must identify `github.com/Simon-Initiative/oli-torus` (SSH or HTTPS, optional `.git`). A directory name alone is insufficient. Outside this repository, stop and explain the scope, even for explicit invocation. Do not switch repositories automatically.
2. Read applicable `AGENTS.md` instructions. Use the installed `jira` CLI for all Jira operations, subject to the availability fallback above. Consult CLI help when flags or output fields are unclear.
3. Extract and uppercase the `MER-<digits>` key from the supplied ID or URL. If the intended ticket is ambiguous, ask for it. Read `jira issue view <KEY> --plain` and verify the actual issue type is Story, Bug, or Task. Do not infer type from the user's wording or invent missing issue data.
4. Inspect the current branch, `git status --short`, `git worktree list --porcelain`, local branches, and remotes. Preserve uncommitted work. Do not stash, reset, clean, commit, or force checkout automatically. If changing branches would carry unrelated edits into the new task or conflict with a checkout, complete independent setup and ask how to handle those edits.
5. Retrieve the parent's complete sub-task list, including keys, summaries, and statuses. Use the parent issue and, if needed, `jira issue list --parent <KEY> --plain --no-truncate --columns KEY,TYPE,SUMMARY,STATUS`; handle pagination. A failed or incomplete query is not evidence that there are no sub-tasks.

## Choose names and base

Map the Jira type to the integration prefix and use the ticket's summary for the description:

| Jira type | Branch example                   |
| --------- | -------------------------------- |
| Story     | `story/MER-1234-some-feature`    |
| Bug       | `bug/MER-1234-some-bug`          |
| Task      | `task/MER-1234-some-task`        |
| Sub-task  | `sub-task/MER-1235-some-subtask` |

Keep the ticket key uppercase. Make the summary lowercase kebab-case: replace runs of spaces or punctuation with a single hyphen and trim leading/trailing hyphens. Preserve meaningful words; if no usable slug remains, derive a short description from the ticket. Validate every proposed name with `git check-ref-format --branch` and quote shell arguments safely.

For a new integration branch, use an explicitly requested base; otherwise use `origin/master`, not the current branch or local `master`. Refresh the relevant remote refs without changing local branches. Resolve the base to a commit once and record it for this setup. If fetching or resolving the base fails, report the blocker instead of silently using a stale or different base.

Use the recorded base commit for the new integration branch. After creating or identifying the parent integration branch, resolve its current tip separately and use that commit as the new sub-task branch base. Prefer the refreshed remote integration ref when it exists; otherwise use the local integration branch. If local and remote integration tips differ, report the difference and resolve which tip to use before creating a child branch; do not silently discard or incorporate local-only work.

This applies even to a small ticket with one sub-task. When both branches are new, their initial commits coincide; when the integration branch already contains work, the child inherits that work rather than starting again from `origin/master`. A base override for the integration branch does not change this parent-child relationship. The documented exception is a dependent sub-task: when explicitly requested, branch from the prerequisite implementation branch, but keep the parent integration branch as the PR target. Existing branches retain their commits; do not rebase or reset them during setup.

## Create or reuse branches safely

Apply these rules separately to the integration branch and selected sub-task branch:

- Before creation, inspect local and remote branches for both the proposed name and an existing branch with the same type and exact ticket key, allowing existing prefix case variants. A changed summary must not create a duplicate branch for the same ticket. Existing `integ-*` integration branches remain supported: reuse one when its association with the parent is established by the user or repository/ticket evidence; do not infer that association from a vague name. If multiple distinct names match, ask which to use. Use the type-based naming table for new integration branches.
- Refresh/check relevant remotes so a branch that exists only remotely is not mistaken for a new branch. If existence cannot be determined, stop that branch operation.
- If the branch exists locally, reuse it without moving its tip. If the same name exists locally and remotely with different commits, preserve both; do not reset, merge, or rebase as part of setup.
- If it exists only remotely, create a local tracking branch at the remote branch's existing commit. This reuses the existing branch; it does not initialize it from the new-ticket base. If multiple remotes offer conflicting candidates, ask which one to use.
- Only when absent locally and remotely, create it with `git branch <name> <branch-specific-base-commit>` using the integration or sub-task base resolved above. Use ordinary non-forcing commands so a concurrent creation fails safely. Never delete, overwrite, rename, or force-update an existing branch.
- If a required branch is checked out in another worktree, report that worktree and ask how to continue. Do not bypass Git's protection or create duplicate branches to work around it.

Create or reuse the integration branch first. It need not be checked out to create the work branch. Do not push either branch unless separately requested.

## Follow the integration process

Keep the following destinations and requirements explicit in the setup handoff:

- Track all implementation work in child Sub-tasks. Each `sub-task/*` PR targets its parent integration branch, including tickets with only one implementation PR. All PRs into integration branches, including implementation and sync PRs, use **Create a merge commit** after developer approval and required status checks pass. Sub-task branches cannot merge directly into `master`.
- Publish a new integration branch at its starting commit when publishing is requested. It must be protected from subsequent direct pushes as soon as it exists; all development changes arrive through reviewed PRs. Required protections include approvals and status checks, blocked direct and force pushes (including maintainer bypass), and restricted deletion. Local branch creation alone does not establish these protections.
- Before using the integration branch as a remote PR target, verify the applicable ruleset and CI coverage described in [Rollout Requirements](guides/process/development.md#rollout-requirements). The guide records rollout prerequisites for `story/*`, `bug/*`, and `task/*`; a valid branch name or successful push does not prove protections or required checks are configured. Report unverified or missing prerequisites without changing repository settings as part of setup.
- Once implementation Sub-tasks have merged, open the integration PR to `master` for acceptance testing, or mark an existing draft ready for review. A draft integration PR may be opened during development when a preview deployment is requested. QA tests the integration PR's preview at the current head revision; fixes and syncs require testing the updated revision. Submit the integration PR to the `master` merge queue only after acceptance testing, QA approval, and required checks pass. Do not open an integration PR merely because the branches were created.
- Downmerge `master` and resolve integration conflicts through a reusable `sync/<parent-key>-<summary>` branch based on and targeting the integration branch, with the summary copied exactly from that parent branch. Reference the parent ticket in the sync branch and PR; no child Sub-task is required for syncing or resolving its conflicts. For requested sync work, follow [the sync workflow](references/sync.md). Merge sync PRs with a merge commit to preserve ancestry. Do not merge or push synchronization changes directly into the integration branch during setup.
- For the dependent-PR exception, merging the prerequisite PR preserves its commits, so the dependent branch does not need to be rebased because the prerequisite merged. Merge newer integration changes into the dependent branch when needed; that later update is outside this setup operation.

An Epic groups parent tickets and does not receive a shared integration branch. Existing `integ-*` branches follow the same review and completion process. Do not create sync branches, publish branches, open PRs, or change rulesets merely to satisfy this handoff; perform those operations only when requested.

## Select the sub-task

- Honor an explicitly selected sub-task after verifying it belongs to this parent.
- With one existing sub-task, use it unless it is completed or canceled; in that case ask how to proceed rather than reopening it.
- With multiple sub-tasks, default to the first not started: statuses `Analyzing` or `To Do`, ordered by ascending numeric MER ticket ID. Report this ordering and the selected ticket. If the project uses another unstarted status, establish its meaning before including it. Do not select an in-progress or completed ticket ahead of an eligible unstarted ticket.
- If none of several sub-tasks is unstarted, show their statuses and ask which to resume. Do not create another ticket or reopen completed work automatically.
- With no sub-tasks, after creating or reusing the integration branch, offer one sub-task covering the parent's work. Draft its exact project (`MER`), type (`Sub-task`), parent key, summary, and description from the parent's scope and acceptance criteria. Do not invent additional scope. Include any required fields. Obtain approval before creating the ticket, then use its returned key and summary for the work branch. If declined, retain the integration branch and report that the work branch remains pending; do not fabricate a ticket key.

For an existing selected sub-task, read `jira issue view <SUBTASK-KEY> --plain`, create or reuse its branch, and switch to it with `git switch <name>` when safe. For a newly created sub-task, do this after its creation and read-back. Do not create branches for every sub-task.

## Approve and perform Jira changes

When Jira CLI access is unavailable, skip these writes and provide the manual instructions described above. Otherwise, present the exact proposed changes and obtain explicit user approval before making any changes in Jira, including creating tickets or changing their status. Starting work is not approval of unseen changes. Complete the authorized Git setup and read-only inspection before presenting the remaining Jira actions together for approval. Reuse approval already given for the exact actions; do not ask again unnecessarily.

For a parent in `Analyzing` or `To Do`, propose moving it to `In Progress`. For the selected sub-task in either of those statuses, propose the same transition independently, including when the parent is already `In Progress`. Leave tickets already `In Progress` unchanged. Do not reopen completed tickets or force other statuses through a transition without resolving the intended action with the user.

Show each ticket's key, current status, and requested status. When offering a new sub-task, combine its full draft and the intended transitions for the parent and newly created child in one approval request where possible. The child's future transition can be approved as part of that exact creation draft even though its key is not yet assigned. If approval is declined, keep the prepared branches and report the pending or declined Jira actions accurately.

After approval:

1. Recheck the relevant tickets and sub-task list before writes. If another sub-task appeared or the proposed changes materially differ, reconcile the plan before creating a duplicate or applying stale changes.
2. For an approved new sub-task, put the exact description in a temporary UTF-8 file outside the repository and use `jira issue create --project MER --type Sub-task --parent <PARENT-KEY> --summary <approved-summary> --template <file> --no-input`. Use the issue type spelling supported by the project. Capture the returned key; do not predict it.
3. Read the created issue back with `jira issue view <KEY> --plain`. Verify its type, parent, summary, description, and formatting. Check headings, paragraphs, lists and nested lists, task checkboxes, code paths, and links when present. Correct malformed formatting without changing approved meaning, then read it back again. Create/reuse and check out its branch as described above.
4. Before editing each existing ticket, read its current contents with `jira issue view <KEY> --plain`. If it is already at the approved target, skip the write. Otherwise apply only the approved transition with `jira issue move <KEY> "In Progress"`. Read it back after each write and verify the status and retained content. If the transition is unavailable, report the blocker; do not substitute another state.
5. If a Jira write returns an ambiguous result, read back or query for the issue before retrying. Do not create duplicates or repeat transitions blindly. Remove only temporary files created by this workflow.

## Verify and report

Verify the two local branch refs and the checked-out branch. For newly initialized branches, confirm the integration branch starts at its recorded base and the sub-task branch starts at the resolved parent integration tip (or explicitly selected dependency branch); for reused branches, confirm their tips were preserved. Report the parent and selected sub-task links, each branch name and whether it was created or reused, each branch's base, the active work branch, and Jira statuses only when verified. Include skipped Jira steps and the manual actions still required. State that the sub-task PR targets the integration branch and the completed integration PR targets `master` through the merge queue. Distinguish completed local setup from remote publication and verified protection/CI readiness. Explicitly identify any pending approval, skipped transition, or checkout blocker instead of claiming complete setup.
