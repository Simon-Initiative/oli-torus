# PR processes

## Story, Bug, and Task development

Follow the [Development Process](development.md) for branch setup, PR destinations, reviews, acceptance testing, syncs, and merging.

Prefix PR titles and merge commit messages with the change type, ticket reference, and description, for example `[BUG FIX] [MER-1001] Fix dashboard loading`. Use the child Sub-task ticket for implementation PRs and the parent ticket for integration and sync PRs.

### Valid Change Types

- `[FEATURE]`: New feature for the user
- `[ENHANCEMENT]`: Small improvements to existing features
- `[BUG FIX]`: Bug fix for an existing feature
- `[CHORE]`: Updating of build infrastructure, deployment automation, branch merging, docs, etc.
- `[PERFORMANCE]`: Changes that target a performance improvement

### Valid ticket references

- `[MER-xxxx]`: MER board tickets
- `[NG23-xxxx]`: NG board tickets
