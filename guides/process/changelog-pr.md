# Changelog processes

## Feature development / bug fixing

1. Developer performs feature work or bug fix on a branch off of `master`.
2. Developer opens a pull request against `master` once the work is completed. The PR should include a change to `CHANGELOG.md` summarizing the work.
3. Reviewer reviews the PR and either requests changes or approves.
4. After approval, the reviewer **squashes and merges** to master, updating the commit message to summarize the entirety of the work item. This aggregate commit message must be prefixed with the change type, a description, and a reference to the pull request number. For example, `[BUG FIX] A description #123 CMU-30` or `[FEATURE] Another description #231 CMU-30`. It should also include a reference to the Argos JIRA ticket number.

### Valid Change Types

- `[FEATURE]`: New feature for the user
- `[BUG FIX]`: Bug fix for an existing feature
- `[DOCS]`: Changes purely to documentation
- `[REFACTOR]`: Refactoring of code, no changes in functionality
- `[CHORE]`: Updating of build infrastructure, deployment automation, etc.
- `[PERF]`: Changes that target a performance improvement
- `[ENHANCEMENT]`: Small improvements to existing features

![changes](assets/message.png "Message")

## Release

1. Developer opens a PR against `master` to update the version in `mix.exs` and to update the release date within `CHANGELOG.md`.
1. PR lands to `master` with a commit message of `[RELEASE] x.y.z` with the appropriate version number.
1. A [Github Release](https://github.com/Simon-Initiative/oli-torus/releases) is created with the **Tag version** and **Release title** formatted as `vx.y.z` (e.g. `v1.0.0`) and the corresponding list of **Enhancements** and **Features** as well as any other relevant information for the release copied from `CHANGELOG.md` into the description.
1. A PR is opened to merge `master` to `test`, after it builds and merged any required testing is done on `tokamak.oli.cmu.edu`
1. A PR is opened to merge `master` to `prod`. After it builds it is merged to trigger the deployment to production.

## Examples

The following is an example of what the above guidelines yield in the commit history on `master`:

```
[RELEASE] v0.4.1
[BUG FIX] Restored ability to sort media items by size #324
[BUG FIX] Corrected position of image thumbnails within media library #345
[FEATURE] Added new Ordering activity type #346
```
