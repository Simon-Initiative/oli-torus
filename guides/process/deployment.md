# CI/CD and Deployment Process

## Overview

Torus uses Github Actions for its CI/CD pipelines. When a PR is opened, a build is automatically started and several checks are run including unit tests and lint checks which must all pass before a PR can be merged. Once a branch is merged into master, the resulting commit is packaged and deployed to the test server ([tokamak.oli.cmu.edu](https://tokamak.oli.cmu.edu)). The test server will always represent the latest from master unless a manual deployment is made. When a release is made (tagged vX.Y.Z), a deployment is kicked off to the production server ([proton.oli.cmu.edu](proton.oli.cmu.edu)). A production deployment will always use a prebuilt artifact identified by the version and commit SHA to ensure that the release tested is the same as the release deployed.

**Test Server:** [tokamak.oli.cmu.edu](tokamak.oli.cmu.edu)

**Production Server:** [proton.oli.cmu.edu](proton.oli.cmu.edu)

## Pull Requests

Every pull request is required to pass a set of status checks in both Elixir and Typescript including a successful build, all unit tests passing, and successful lint with no errors (TypeScript). These checks are automatically started when a pull request is created. Other automated checks include Coveralls for unit test coverage and GitGuardian for identifying accidentally leaked secrets, however these checks are only informative and discretion is left to the developer and code reviewer to decide if issues found are blocking.

## Deployments to Test

Deployments to the test server are automatically initiated when a pull request is landed to master. This means the test server will usually be up-to-date with the latest changes from the master branch. There are some situations however, when someone may want to manually push a deployment to the test server which can be accomplished with the following:

### Release Candidates

If a release candidate is created with a tag formatted as `vX.Y.Z-rcN` where X.Y.Z represents a version number and N is the release candidate number, a deployment of the tag's targeted ref will be deployed to the test server.

1. Go to https://github.com/Simon-Initiative/oli-torus/releases and click "Draft a new release"
1. Enter your vX.Y.X-rcN for **Tag version** and **Release Title**
1. Add the Features and Bug Fixes sections (formatted as markdown) to the description
1. Check "This is a pre-release"
1. Click "Publish release"

### `deploy-test` Tag

A deployment can be initiated by tagging any git ref with the `deploy-test` tag and pushing to remote. For example:

```
git tag --delete deploy-test   # if the tag previously existed locally
git tag deploy-test
git push origin deploy-test --force
```

## Deployments to Production

Deployments to the production server will be initiated when a release is created with the tag formatted as `vX.Y.Z` where X.Y.Z represents a version number.

> **Note:** Production deployments assume a previous build has been packaged, and therefore any commit tagged as a release must exist on the `master` branch, a `hotfix|prerelease-*` branch or be packaged by tagging the commit with the `package` tag first.

## Hotfixes

A hotfix branch can be created using the release tag you wish to branch from. For example:

```
git checkout -b hotfix-X.Y.[Z+1] vX.Y.Z
git push origin hotfix-X.Y.[Z+1]
```

Once the hotfix branch is created, it will essentially act as the master branch to land all bug fixes and enhancements that are intended to be included in the hotfix.

When a hotfix branch is ready to be deployed, it can be tagged using the **Release Candidate** and **Deployment Process** outlined above. Hotfix branches that follow the convention `hotfix-` will automatically be packaged when pushed to remote, just like master. Make sure to wait for the package step to complete before creating a release, or else the deployment will fail.

> **Note:** Because hotfix branches are automatically packaged based on the branch name convention, there is no need to manually tag with `package` before deploying.

Finally, make sure the hotfix branch is eventually merged back to master to be included in downstream development. To do this easily, create a new branch from the hotfix branch called `integrate-X.Y.Z` (the name here is not necessarily important, but just serves as an example). Then pull `master` into this integration branch. Once any/all merge conflicts are resolved, open a PR against master.
