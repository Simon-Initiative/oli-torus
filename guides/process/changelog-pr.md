# PR processes

## Feature development / bug fixing

1. Developer performs feature work or bug fix on a branch off of `master`.
2. Developer opens a pull request against `master` once the work is completed.
3. Reviewer reviews the PR and either requests changes or approves.
4. After approval, the reviewer **squashes and merges** to master, updating the commit message to summarize the entirety of the work item. This aggregate commit message must be prefixed with the change type, a ticket reference and a description. For example, `[BUG FIX] [MER-1234] A description` or `[FEATURE] [NG23-29] Another description`.

### Valid Change Types

- `[FEATURE]`: New feature for the user
- `[ENHANCEMENT]`: Small improvements to existing features
- `[BUG FIX]`: Bug fix for an existing feature
- `[CHORE]`: Updating of build infrastructure, deployment automation, branch merging, docs, etc.
- `[PERFORMANCE]`: Changes that target a performance improvement

### Valid ticket references

- `[MER-xxxx]`: MER board tickets
- `[NG23-xxxx]`: NG board tickets