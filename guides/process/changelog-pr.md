# PR processes

## Feature development / bug fixing

1. Developer performs feature work on a branch off of that feature's integration branch (see [Feature Integration Branches](deployment.md#feature-integration-branches)). A feature is one standalone Jira Story; its implementation work is captured in child Tasks. Bug fixes and other non-feature work continue to branch from `master` until their process is defined separately.
2. Developer opens a feature implementation pull request against the feature integration branch once the work is completed. Non-feature work opens a pull request against `master`.
3. Reviewer reviews the PR and either requests changes or approves.
4. After approval, the reviewer **squashes and merges** a regular PR to its base branch. For PRs targeting `master`, update the aggregate commit message to summarize the entirety of the work item. This aggregate commit message must be prefixed with the change type, a ticket reference and a description. For example, `[BUG FIX] [MER-1234] A description` or `[FEATURE] [NG23-29] Another description`.
5. Merge the final PR from a feature integration branch into `master` with a maintainer-performed merge commit, as described in [Feature Integration Branches](deployment.md#merging-an-integration-branch-to-master).

### Valid Change Types

- `[FEATURE]`: New feature for the user
- `[ENHANCEMENT]`: Small improvements to existing features
- `[BUG FIX]`: Bug fix for an existing feature
- `[CHORE]`: Updating of build infrastructure, deployment automation, branch merging, docs, etc.
- `[PERFORMANCE]`: Changes that target a performance improvement

### Valid ticket references

- `[MER-xxxx]`: MER board tickets
- `[NG23-xxxx]`: NG board tickets
