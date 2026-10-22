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

Follow the [Development Process](../guides/process/development.md) for branch setup, implementation and sync PRs, acceptance testing, and merging. See [PR conventions](../guides/process/changelog-pr.md) for change types and ticket references.

When work is being executed through Harness Engineering, the Jira issue description, comments, and linked design context form the informal input that feeds PRDs, plans, and implementation work.
