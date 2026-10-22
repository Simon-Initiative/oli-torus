# Issue Tracking

## System Of Record

Jira is the system of record for Torus feature work, bugs, and execution tracking.

- Internal project board: <https://eliterate.atlassian.net/jira/software/c/projects/MER/boards/2/backlog>
- Public guest-facing bug intake board: <https://eliterate.atlassian.net/jira/software/c/projects/TRIAGE/boards/15>
- Install the Jira CLI: <https://github.com/ankitpokhrel/jira-cli>
- Install the `jira` skill in the user-level agent skills directory so agents can inspect and work with Jira issues more efficiently

## Intake Workflow

Use the internal MER project board for normal engineering planning, backlog management, and implementation tracking.

Use the TRIAGE board when non-authenticated or guest users need a public-facing path to report bugs.

Each parent Story, Bug, or Task has a protected integration branch (`story/*`, `bug/*`, or `task/*`). Track implementation work in child Sub-tasks and open implementation PRs against that integration branch. Once the parent ticket's work and acceptance testing are complete, open its integration PR against `master` and use the merge queue. Use the parent integration ticket directly for syncs from `master`, including conflict resolution; no child Sub-task is required. Use that parent key in `sync/<parent-issue-key>-<summary>` and in the reviewed sync PR back into the integration branch. Copy the summary from the parent integration branch and reuse the same sync branch across syncs. See `guides/process/changelog-pr.md` and `guides/process/development.md` for the full process.

When work is being executed through Harness Engineering, the Jira issue description, comments, and linked design context form the informal input that feeds PRDs, plans, and implementation work.
