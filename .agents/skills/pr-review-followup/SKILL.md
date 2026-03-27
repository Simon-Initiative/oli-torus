---
name: pr-review-followup
description: >
  Triage and address pull request review comments after a PR is open. Use when Codex should read the linked ticket if present, the PR description, the relevant Torus review guidelines, and all review comments to build context first; then classify comments internally, review them interactively with the user one by one, agree on an action per comment, implement only the approved changes, create a single follow-up commit, and reply thread-by-thread for anything deferred, clarified, or not taken.
examples:
  - "Use pr-review-followup on PR 9123"
  - "Review the comments on my current PR and let's decide which ones to take"
  - "@codex handle the review comments on this branch"
when_to_use:
  - "A GitHub PR already exists and review comments need triage, follow-up changes, or thread replies."
  - "The branch may need small code changes plus explicit responses for comments that are deferred, unclear, or already handled."
  - "You want an interactive pass with the user before editing code or replying on GitHub."
when_not_to_use:
  - "The task is a first-pass code review of a diff that does not yet have review comments."
  - "The user only wants a local code review of unsubmitted changes."
  - "There is no PR context, ticket, or review thread to triage."
---

## Purpose

Use this skill after a PR is open and review comments already exist.

The goal is to build full PR context first, classify review comments before proposing action, then walk the user through the actionable set one comment at a time. Do not start coding or replying on GitHub before the user approves the reviewed plan.

Prefer `gh` for PR discovery, PR metadata, linked issue retrieval, and review thread retrieval. If the PR number is not given, detect it from the current branch first.

## Required Resources

Always load before presenting recommendations:

- `.review/security.md`
- `.review/performance.md`

Load conditionally based on the scope of the PR:

- `.review/elixir.md`
  - when the PR changes backend or Elixir code
- `.review/ui.md`
  - when the PR changes UI or frontend behavior
- `.review/requirements.md`
  - when the PR adds or changes `docs/exec-plans/**/prd.md`

Use local code and PR metadata as primary context:

- linked ticket, if present
- PR title and description
- review comments and review-thread state
- current branch diff and relevant files

## Workflow

1. Locate the PR.
   - Use `gh pr status` or `gh pr view` for the current branch when the PR number is not provided.

2. Build context before triaging.
   Read:
   - the linked ticket, if there is one
   - the PR title and description
   - all review comments and bot comments
   - the relevant `.review/` guidelines for the changed scope

   Extract the declared scope, explicit non-goals, follow-up work, and any ticket constraints. Treat this as required context for all later recommendations.

3. Classify comments internally before presenting anything.
   Do this in the background first. Do not immediately stream a recommendation per comment.

   Supported actions:
   - `implement`
   - `reply-and-defer`
   - `reply-and-ask`
   - `ignore`
   - `already-addressed`
   - `auto-ignore`

   For each comment, also record:
   - visible author name
   - author type: `ai_bot` or `human`
   - bot subtype when identifiable, such as `performance`, `security`, `requirements`

4. Auto-ignore clearly non-actionable bot comments before presenting anything.
   Use `auto-ignore` for:
   - AI bot comments that explicitly say no issues were found
   - informational risk or status comments with no requested change
   - CI or tooling noise unrelated to the PR code
   - duplicate bot comments that add no value beyond an already-triaged human comment

   Do not use `auto-ignore` when a bot comment contains a concrete requested change, even if it is minor or likely out of scope.

5. Present an initial summary to the user.
   Do not start implementing yet.

   Distinguish clearly between:
   - comments that need user review
   - comments auto-ignored as non-actionable bot noise

   Summarize:
   - total number of comments
   - total number of comments, split as `(X AI bot, Y human)`
   - count by suggested action
   - count of `auto-ignore` comments
   - number of comments that will be reviewed interactively
   - short explanation of why the `auto-ignore` set is being skipped
   - short high-level situation summary

   Make it explicit that `auto-ignore` comments will not be reviewed one by one unless the user asks.

6. Review comments interactively, one by one.
   Only review comments that are not classified as `auto-ignore`.

   For each comment, present:
   - `Comment`
   - `Author`
   - `What It Is Asking`
   - `Context`
   - `Suggested Action`
   - `Why`
   - `Proposed Resolution`

   If the proposed resolution depends on a Torus review rule, say which `.review/` guideline materially affected the recommendation.

7. End each comment review with exactly two options.

   For non-final comments:
   1. `accept and continue`
   2. `adjust`

   For the final comment:
   1. `accept and view final summary`
   2. `adjust`

8. Support iterative adjustment on the same comment.
   If the user chooses `adjust`, continue iterating on that same comment until a final proposal is agreed. Do not advance until the user accepts.

9. After all comments are reviewed, present a final execution summary.
   Show a compact mapping of:
   - comment -> agreed action

   Separate clearly:
   - code changes to implement
   - PR replies to post
   - open questions or clarification replies

10. Wait for explicit user approval before executing.
    Do not edit files, post comments, create commits, or push anything before the user approves the final summary.

11. Execute the agreed plan.
    - implement all approved code changes
    - if Elixir files changed, run `mix format` on the touched files before final verification
    - if files under `assets/` changed, run the narrowest relevant frontend checks for the touched behavior
    - run the narrowest relevant tests or checks for the touched behavior
    - create a single commit for all accepted changes
    - before any `git push`, explicitly tell the user that push is the next step and that you are about to do it
    - after the push completes, send a short final completion message that makes it explicit the follow-up is finished end-to-end

    Preferred commit message:
    `addressed review comments: <brief summary>`

12. Reply thread-by-thread for everything not implemented.
    Post separate replies for:
    - deferred comments
    - clarification requests
    - comments already addressed
    - comments intentionally not taken, when a response is appropriate

    Prefer replying in each original thread instead of leaving one aggregate PR comment.

## Decision Rules

Evaluate every comment against:

- the linked ticket
- the PR description
- the actual code in the branch
- the relevant Torus `.review/` guidance

Prefer `implement` when the comment is:

- a correctness bug within current scope
- a security problem
- a crash or reliability issue
- a small, low-risk improvement that belongs in this PR

Prefer `reply-and-defer` when the comment is:

- valid but outside current PR scope
- explicitly deferred by the ticket or PR description
- a larger refactor than this slice justifies
- a broader improvement better handled in follow-up work

Prefer `reply-and-ask` when the comment is:

- ambiguous
- based on missing context
- in tension with ticket scope or product intent
- likely to require a user or reviewer decision

Prefer `ignore` when the comment is:

- obsolete
- duplicate
- superseded by later discussion
- not useful enough to warrant response

Prefer `auto-ignore` when the comment is:

- clearly informational bot output with no requested action
- a no-findings AI bot comment
- CI or tooling noise not tied to the branch code
- a duplicate bot comment that is fully covered by another triaged comment

Prefer `already-addressed` when the comment is:

- already resolved in the branch
- already reflected in the PR state
- better answered by pointing to the existing code change

## Guardrails

- Do not assume every review comment should be implemented.
- Do not start coding before the user approves the reviewed set of actions.
- Do not batch controversial changes without user agreement.
- Do not rewrite large areas of the PR to satisfy speculative comments.
- Do not post PR comments before alignment with the user, unless the user explicitly asks for immediate posting.
- Do not create multiple commits for accepted review fixes unless the user asks for that.
- Do not run broad test suites when narrow verification is enough.
- Keep the initial summary concise and go deep only on the current comment under review.
