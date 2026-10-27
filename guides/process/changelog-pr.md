# PR processes

## Story, Bug, and Task development

Follow the [Development Process](development.md) for branch setup, PR destinations, reviews, acceptance testing, syncs, and merging.

Prefix PR titles and merge commit messages with the change type, ticket reference, and description, for example `[BUG FIX] [MER-1001] Fix dashboard loading`. Use the main ticket for implementation PRs unless the work is tracked in a chosen child Sub-task, in which case use that child ticket. Integration and sync PRs always reference the main ticket.

### Valid Change Types

- `[FEATURE]`: New feature for the user
- `[ENHANCEMENT]`: Small improvements to existing features
- `[BUG FIX]`: Bug fix for an existing feature
- `[CHORE]`: Updating build infrastructure, deployment automation, docs, and other maintenance
- `[SYNC]`: Synchronizing branches, including merging `master` into an integration branch
- `[PERFORMANCE]`: Changes that target a performance improvement

### Valid ticket references

- `[MER-xxxx]`: MER board tickets
- `[NG23-xxxx]`: NG board tickets
