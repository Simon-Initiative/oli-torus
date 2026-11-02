# Deployment Process

## Overview

Torus uses GitHub Actions to package and deploy releases. Merging into `master` packages the resulting commit and deploys it to the test server, which normally runs the latest `master` unless a manual deployment is made. Production uses the same prebuilt artifact deployed to the test and QA environments which is identified by its version and commit SHA so the verified artifact is identical to the one deployed to production.

For pull requests, integration branches, CI checks, and the merge queue, see the [Development Process](development.md).

**Test Server:** [tokamak.oli.cmu.edu](https://tokamak.oli.cmu.edu)

**QA Server:** [stellarator.oli.cmu.edu](https://stellarator.oli.cmu.edu)

**Production Server:** [proton.oli.cmu.edu](https://proton.oli.cmu.edu)

## Deployments to Test

Deployments to the test server are automatically initiated when a pull request is landed to master. This means the test server will usually be up-to-date with the latest changes from the master branch.

### Release Candidates

A release candidate can be created with a tag formatted as `vX.Y.Z-rcN` where X.Y.Z represents a version number and N is the release candidate number. Because the release candidate is created from a commit on the master branch, it will have a deployable package artifact which can be deployed to any supported QA environment. To create a release candidate, follow these steps:

1. Go to https://github.com/Simon-Initiative/oli-torus/releases and click "Draft a new release"
1. Enter your vX.Y.X-rcN for **Tag version** and **Release Title**
1. Add the Features and Bug Fixes sections (formatted as markdown) to the description
1. Check "This is a pre-release"
1. Click "Publish release"

## Deployments to Production

Deployments to the production server can be initiated by manually invoking the 'Deploy' workflow from the GitHub Actions tab. The workflow will prompt for the version to deploy, which must be a tag that exists on the `master`. The deployment requires an approval from authorized personnel before it can proceed. The workflow will then deploy the tagged package release to the production server.

> **Note:** Production deployments assume a previous build has been packaged, and therefore any commit tagged as a release must exist on the `master` branch, a `prerelease-*` branch or be packaged by manually invoking the 'Package' workflow first.
