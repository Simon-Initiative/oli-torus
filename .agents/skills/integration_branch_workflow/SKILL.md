---
name: integration_branch_workflow
description: Set up or sync Jira MER integration branches in Simon-Initiative/oli-torus. Use for "let's begin work on MER-1234", "Create an integration branch for MER-1234", "Set up branches for MER-1234", "sync MER-1234 integration branch", "update my integration branch for MER-1234 with the latest", or "pull the latest from master into my integration branch", including Jira URLs. Set up integration and working branches with optional subtasks, or merge master through a sync branch with automatic/manual conflict resolution and a PR to the integration branch. Do not use outside oli-torus, for epics, or for read-only ticket lookups.
---

# Integration Branch Workflow

Support two operations:

- **Start work:** Prepare the integration branch and one working branch using the main ticket or a chosen sub-task, ending on the working branch. Developers decide whether to split work into zero or more sub-tasks. Follow the setup workflow below; setup alone does not implement the ticket, push branches, or open PRs.
- **Sync with master:** Follow [Sync an integration branch](references/sync.md) to merge the latest master into a separate sync branch, resolve conflicts with the engineer's chosen mode, and open or reuse a PR targeting the integration branch. Do not run the start-work sub-task selection or create an implementation branch for a sync request.

Follow [Integration Branches](guides/process/development.md#integration-branches) in the verified oli-torus checkout. Resolve this repository-relative link from the checkout root, not the skill directory. Read that section and its subsections during setup; it defines the branch ancestry, PR destinations, protections, and completion process. If it cannot be read, report the missing guidance before creating branches.

## Jira access and provider selection

These rules apply to both setup and sync. Use either an authenticated Atlassian MCP connection or the installed, configured `jira` CLI; never require both. Discover the available Jira MCP tools and their supported operations. Check `command -v jira` when CLI access is needed, and use the first required read to establish access to the intended Jira site/project. Treat authentication, permission, or unsupported-operation failures as unavailable access for that operation, using the other provider if available. Inspect ambiguous writes before any fallback retry. Do not inspect or print credentials.

- **MCP only:** Use its supported Jira reads and authorized writes without requiring CLI installation or configuration.
- **CLI only:** Use the CLI without requiring an MCP connection. Consult CLI help when flags or output fields are unclear.
- **Both:** Prefer MCP for each operation it supports; use CLI for operations MCP cannot perform. Keep the same Jira site/project and ticket context across providers. After an ambiguous write, inspect Jira before retrying through either provider.
- **Neither, or no available provider supports the required operation:** Skip the affected Jira step and continue independent Git/GitHub work with the information available. Tell the engineer what is unavailable and which Jira information or manual actions are needed. Do not switch to browser automation or direct REST, repeatedly retry unavailable operations, or require installation/configuration of another provider before continuing unrelated work. Do not install tools or change credentials automatically.

All Jira reads and writes below are conditional on access through a provider that supports the operation. CLI commands are examples only when using CLI; for MCP, use the discovered tools with equivalent fields and verify the same results. When a step is skipped:

- Use ticket details supplied by the engineer and established branch/PR context; label Jira details that could not be verified. Never invent ticket keys, summaries, parent relationships, types, or statuses. Ask only for missing information needed for the next dependent action, such as a new integration ticket's type and summary or the selected child ticket's key.
- A failed sub-task lookup does not mean no sub-tasks exist. If the engineer chose to work directly on the main ticket, continue with its known key and branch context. Otherwise ask whether to use the main ticket or have the engineer identify a child in Jira. Only a chosen child branch requires that child's real ticket key; never require child creation to continue with the main ticket.
- For skipped status changes, instruct the engineer to move the main ticket and any selected child from `Analyzing` or `To Do` to `In Progress` if applicable. If the current status could not be read, make that instruction conditional; do not claim the status was changed.
- If a write may have succeeded before access failed, tell the engineer to inspect Jira for the result before repeating it manually. Do not report an unverified write as completed or create duplicate tickets.
- In the final handoff, list the specific manual Jira actions and known ticket links alongside the completed Git/GitHub work. Syncs use the parent ticket directly and require no child-ticket creation or status changes; report any parent details that could not be verified.

If access becomes available later, resume only outstanding Jira operations under the normal approval and read-back rules.

## Start-work setup

### Confirm scope and inspect

1. Before querying Jira or changing Git state, verify the current checkout or worktree with `git rev-parse --show-toplevel` and `git remote -v`. A remote must identify `github.com/Simon-Initiative/oli-torus` (SSH or HTTPS, optional `.git`). A directory name alone is insufficient. Outside this repository, stop and explain the scope, even for explicit invocation. Do not switch repositories automatically.
2. Read applicable `AGENTS.md` instructions. Apply [Jira access and provider selection](#jira-access-and-provider-selection) for all Jira operations.
3. Extract and uppercase the `MER-<digits>` key from the supplied ID or URL. If the intended ticket is ambiguous, ask for it. Read the issue through the selected provider (CLI example: `jira issue view <KEY> --plain`) and verify the actual issue type is Story, Bug, or Task. Include its summary, description, acceptance criteria, status, and relationships needed for the workflow. Do not infer type from the user's wording or invent missing issue data.
4. Inspect the current branch, `git status --short`, `git worktree list --porcelain`, local branches, and remotes. Preserve uncommitted work. Do not stash, reset, clean, commit, or force checkout automatically. If changing branches would carry unrelated edits into the new task or conflict with a checkout, complete independent setup and ask how to handle those edits.
5. Unless the engineer explicitly chooses to work directly on the main ticket, retrieve its complete sub-task list, including keys, summaries, and statuses. Use the parent issue and the selected provider's child lookup/search as needed (CLI example: `jira issue list --parent <KEY> --plain --no-truncate --columns KEY,TYPE,SUMMARY,STATUS`). Follow every page/cursor until the results are complete, and read any omitted child fields separately. Verify the selected child's parent explicitly. A failed, truncated, or incomplete query through either provider is not evidence that there are no sub-tasks.

## Choose the implementation ticket

- Honor an explicit choice to work directly on the main ticket, even when sub-tasks exist. Do not offer or create a sub-task when the engineer declines them.
- With no sub-tasks, use the main ticket for the working branch without requiring a sub-task or another approval to proceed with authorized Git setup.
- Honor an explicitly selected sub-task after verifying it belongs to this parent.
- With one existing sub-task and no explicit choice to use the main ticket, use it unless it is completed or canceled; in that case ask whether to use the main ticket or another sub-task rather than reopening it.
- With multiple sub-tasks and no explicit choice, default to the first not started: statuses `Analyzing` or `To Do`, ordered by ascending numeric MER ticket ID. Report this ordering and the selected ticket. If the project uses another unstarted status, establish its meaning before including it. Do not select an in-progress or completed ticket ahead of an eligible unstarted ticket.
- If none of several sub-tasks is unstarted, show their statuses and ask whether to use the main ticket or which child to resume. Do not create another ticket or reopen completed work automatically.
- If the engineer requests a new sub-task, draft its exact project (`MER`), type (`Sub-task`), parent key, summary, and description from the parent's scope and acceptance criteria. Include required fields and obtain approval before creation. Use its returned key and summary for the working branch. If creation is declined, use the main ticket unless the engineer chooses otherwise; never fabricate a child key.

For an existing selected sub-task, read its details and parent through the selected provider before preparing its branch (CLI example: `jira issue view <SUBTASK-KEY> --plain`). Prepare only the chosen working branch, not branches for every sub-task.

## Choose names and base

Default new integration branches to the main ticket's type prefix and summary. Honor an explicitly requested integration name matching `integ-*`, `story/*`, `bug/*`, or `task/*`:

| Jira type | Branch example                   |
| --------- | -------------------------------- |
| Story     | `story/MER-1234-some-feature`    |
| Bug       | `bug/MER-1234-some-bug`          |
| Task      | `task/MER-1234-some-task`        |

For working branches, suggest `MER-1234-summary` when using the main ticket and retain `sub-task/MER-1235-summary` for chosen sub-tasks. These are conventions, not enforced working-branch names; honor explicit valid names. For example, `integ-MER-1234-summary` and `MER-1234-summary` are an integration/working pair. Keep the two branch refs distinct, and always target the integration branch from the working branch regardless of its name.

When generating default names, keep the ticket key uppercase and make the summary lowercase kebab-case: replace runs of spaces or punctuation with a single hyphen and trim leading/trailing hyphens. Preserve meaningful words; if no usable slug remains, derive a short description from the ticket. Validate every proposed name with `git check-ref-format --branch` and quote shell arguments safely.

For a new integration branch, use an explicitly requested base; otherwise use `origin/master`, not the current branch or local `master`. Refresh the relevant remote refs without changing local branches. Resolve the base to a commit once and record it for this setup. If fetching or resolving the base fails, report the blocker instead of silently using a stale or different base.

Use the recorded base commit for the new integration branch. After creating or identifying the integration branch, resolve its current tip separately and use that commit as the new working branch base. Prefer the refreshed remote integration ref when it exists; otherwise use the local integration branch. If local and remote integration tips differ, report the difference and resolve which tip to use before creating a working branch; do not silently discard or incorporate local-only work.

This applies with or without sub-tasks, including a ticket with only one implementation PR. When both branches are new, their initial commits coincide; when the integration branch already contains work, the working branch inherits that work rather than starting again from `origin/master`. A base override for the integration branch does not change this relationship. The documented exception is a dependent implementation PR: when explicitly requested, branch from the prerequisite implementation branch, but keep the integration branch as the PR target. Existing branches retain their commits; do not rebase or reset them during setup.

## Create or reuse branches safely

Apply these rules separately to the integration branch and working branch:

- Before creation, inspect local and remote branches for both the proposed name and existing branches for the exact ticket key and intended role, allowing existing prefix case variants. An integration branch and a working branch can share the main ticket key; do not treat one as a candidate for the other. A changed summary must not create a duplicate branch for the same role and work. For custom working names, use the engineer's supplied association or existing PR/ticket context rather than assuming a name proves ownership. Reuse `integ-*` integration branches when their association with the main ticket is established by the user or repository/ticket evidence; do not infer that association from a vague name. If multiple candidates remain for a role, ask which to use.
- Refresh/check relevant remotes so a branch that exists only remotely is not mistaken for a new branch. If existence cannot be determined, stop that branch operation.
- If the branch exists locally, reuse it without moving its tip. If the same name exists locally and remotely with different commits, preserve both; do not reset, merge, or rebase as part of setup.
- If it exists only remotely, create a local tracking branch at the remote branch's existing commit. This reuses the existing branch; it does not initialize it from the new-ticket base. If multiple remotes offer conflicting candidates, ask which one to use.
- Only when absent locally and remotely, create it with `git branch <name> <branch-specific-base-commit>` using the integration or working base resolved above. Use ordinary non-forcing commands so a concurrent creation fails safely. Never delete, overwrite, rename, or force-update an existing branch.
- If a required branch is checked out in another worktree, report that worktree and ask how to continue. Do not bypass Git's protection or create duplicate branches to work around it.

Create or reuse the integration branch first. It need not be checked out to create the working branch. Once the chosen ticket is available (after creation and read-back for a requested new sub-task), create or reuse the working branch and check it out with `git switch <name>` when safe. Do not push either branch unless separately requested.

## Follow the integration process

Keep the following destinations and requirements explicit in the setup handoff:

- Track implementation using the main ticket or chosen child Sub-tasks. Each implementation PR targets the integration branch, including tickets with only one implementation PR and fixes during QA. All PRs into integration branches, including implementation and sync PRs, use **Create a merge commit** after developer approval and required status checks pass. Working branches cannot merge directly into `master`.
- Publish a new integration branch at its starting commit when publishing is requested. It must be protected from subsequent direct pushes as soon as it exists; all development changes arrive through reviewed PRs. Required protections include approvals and status checks, blocked direct and force pushes (including maintainer bypass), and restricted deletion. Local branch creation alone does not establish these protections.
- Before using the integration branch as a remote PR target, verify the applicable ruleset and CI coverage described in [Rollout Requirements](guides/process/development.md#rollout-requirements). The guide records rollout prerequisites for `story/*`, `bug/*`, and `task/*`; a valid branch name or successful push does not prove protections or required checks are configured. Report unverified or missing prerequisites without changing repository settings as part of setup.
- Once implementation PRs have merged, open the integration PR to `master` for acceptance testing, or mark an existing draft ready for review. A draft integration PR may be opened during development when a preview deployment is requested. QA tests the integration PR's preview at the current head revision; fixes and syncs require testing the updated revision. Submit the integration PR to the `master` merge queue only after acceptance testing, QA approval, and required checks pass. Do not open an integration PR merely because the branches were created.
- Downmerge `master` and resolve integration conflicts through a reusable `sync/<parent-key>-<summary>` branch based on and targeting the integration branch, with the summary copied exactly from that parent branch. Reference the parent ticket in the sync branch and PR, and use the `[SYNC]` PR type; no child Sub-task is required for syncing or resolving its conflicts. For requested sync work, follow [the sync workflow](references/sync.md). Merge sync PRs with a merge commit to preserve ancestry. Do not merge or push synchronization changes directly into the integration branch during setup.
- For the dependent-PR exception, merging the prerequisite PR preserves its commits, so the dependent branch does not need to be rebased because the prerequisite merged. Merge newer integration changes into the dependent branch when needed; that later update is outside this setup operation.

An Epic groups parent tickets and does not receive a shared integration branch. Existing `integ-*` branches follow the same review and completion process. Do not create sync branches, publish branches, open PRs, or change rulesets merely to satisfy this handoff; perform those operations only when requested.

## PR titles and labels

Apply these conventions when creating or reusing a PR, for both draft and ready PRs and for `story/*`, `bug/*`, `task/*`, and legacy `integ-*` integration branches:

- **Integration PR:** Head is the parent integration branch; base is `master`. Use `[INTEGRATION] [<PARENT-KEY>] <description>` and the exact `Integration Branch` label.
- **Sync PR:** Head is the reusable sync branch; base is its parent integration branch. Use `[SYNC] [<PARENT-KEY>] Sync master into <integration-description>` and the exact `Sync Branch` label.

Use the parent integration ticket in both titles and the first Jira link in the body, even when implementation used Sub-tasks. Implementation PRs keep their appropriate change type and main or selected child ticket; these labels identify the integration and sync routes, not every PR targeting an integration branch.

Use `gh` for GitHub operations. Before publication, verify the exact required label exists in `Simon-Initiative/oli-torus` (for example, `gh label list --repo Simon-Initiative/oli-torus --search <required-label> --json name` and check for an exact name match). If missing or unverifiable, report that prerequisite rather than silently substituting or creating a label. Inspect the PR template and actual stage diff, then check for an existing open PR with the exact head/base to avoid duplicates. Reuse it instead of creating another.

For a new integration PR, write its reviewed body to a temporary UTF-8 file outside the repository and use `gh pr create --repo Simon-Initiative/oli-torus --base master --head <integration-branch> --title <title> --label "Integration Branch" --body-file <file>`. For sync creation, follow [the sync workflow](references/sync.md#publish-the-sync-pr), including `--label "Sync Branch"`. Always pass explicit head/base; use an owner-qualified head for a fork. Add `--draft` when requested; otherwise create a ready PR. On reuse, apply the required title and label with `gh pr edit <url> --repo Simon-Initiative/oli-torus --title <title> --add-label <required-label>`, preserving other labels. Preserve the existing draft/ready state unless a change is authorized; use `gh pr ready <url> --repo Simon-Initiative/oli-torus` when an existing integration draft is authorized to enter acceptance testing.

Read the PR back with `gh pr view <url> --repo Simon-Initiative/oli-torus --json url,title,body,labels,baseRefName,headRefName,isDraft,state`. Verify the exact title, required label, source, target, content, expected draft/ready state, and open state after creation or reuse. After an ambiguous push, creation, or edit result, inspect remote state before retrying. Report the verified URL and any unmet requirements; do not claim publication succeeded based only on a command's exit status. These conventions preserve merge commits into integration branches and the QA-approved `master` merge queue described above.

## Approve and perform Jira changes

When no available Jira provider can perform a required write, skip it and provide the manual instructions described above. Otherwise, present the exact proposed changes and obtain explicit user approval before making any changes in Jira through either provider, including creating tickets or changing their status. Starting work is not approval of unseen changes. Complete the authorized Git setup and read-only inspection before presenting the remaining Jira actions together for approval. Reuse approval already given for the exact actions; do not ask again unnecessarily.

For a main ticket in `Analyzing` or `To Do`, propose moving it to `In Progress`. For a selected sub-task, if any, in either of those statuses, propose the same transition independently, including when the parent is already `In Progress`. When working directly on the main ticket, propose only its transition. Leave tickets already `In Progress` unchanged. Do not reopen completed tickets or force other statuses through a transition without resolving the intended action with the user.

Show each ticket's key, current status, and requested status. When offering a new sub-task, combine its full draft and the intended transitions for the parent and newly created child in one approval request where possible. The child's future transition can be approved as part of that exact creation draft even though its key is not yet assigned. If approval is declined, keep the prepared branches and report the pending or declined Jira actions accurately.

After approval:

1. Recheck the relevant tickets before writes, and the sub-task list when creating or selecting a child. If another sub-task appeared or the proposed changes materially differ, reconcile the plan before creating a duplicate or applying stale changes. A new child does not override an explicit choice to work on the main ticket.
2. For an approved new sub-task, create it through the selected provider with the exact approved project, type, parent, summary, description, and required fields. Use the issue type supported by the project. With CLI, put the exact description in a temporary UTF-8 file outside the repository and use `jira issue create --project MER --type Sub-task --parent <PARENT-KEY> --summary <approved-summary> --template <file> --no-input`. With MCP, supply the equivalent approved fields using the tool's supported description format. Capture the returned key; do not predict it.
3. Read the created issue back through an available provider (CLI example: `jira issue view <KEY> --plain`). Verify its type, parent, summary, description, and formatting. Check headings, paragraphs, lists and nested lists, task checkboxes, code paths, and links when present. Correct malformed formatting without changing approved meaning, then read it back again. Create/reuse and check out its branch as described above.
4. Before editing each existing ticket, read its current contents and available transitions through the selected provider. If it is already at the approved target, skip the write. Otherwise apply only the approved transition (CLI examples: `jira issue view <KEY> --plain`, then `jira issue move <KEY> "In Progress"`). Read it back after each write and verify the status and retained content. If the transition is unavailable, report the blocker; do not substitute another state.
5. If a Jira write returns an ambiguous result, read back or query for the issue before retrying through either provider. For creation without a returned key, inspect the complete parent sub-task list and match the approved details; for a transition, read the current status. Retry only after establishing that the write did not happen. If the result cannot be established, report the uncertainty and defer that write instead of switching providers blindly. Do not create duplicates or repeat transitions blindly. Remove only temporary files created by this workflow.

## Verify and report

Verify the two local branch refs and the checked-out branch. For newly initialized branches, confirm the integration branch starts at its recorded base and the working branch starts at the resolved integration tip (or explicitly selected dependency branch); for reused branches, confirm their tips were preserved. Report the main ticket and any selected sub-task links, each branch name and whether it was created or reused, each branch's base, the active working branch, and Jira statuses only when verified. Include skipped Jira steps and the manual actions still required. State that the implementation PR targets the integration branch and the completed integration PR targets `master` through the merge queue. Distinguish completed local setup from remote publication and verified protection/CI readiness. Explicitly identify any pending approval, skipped transition, or checkout blocker instead of claiming complete setup.
