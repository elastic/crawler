# Releasing

This doc is a reference for Elastic employees.
Non-Elastic users can not publish a release.

The version scheme we use is **MAJOR.MINOR.PATCH** and stored in the [product_version](../product_version) file at the root of this repository.
Open Crawler follows its own release versioning and does not follow the Elastic stack unified release schedule or versioning.

## How to publish a Docker image

Releasing is done entirely through Buildkite.
The Open Crawler build job is named `crawler-docker-build-publish`.

Build steps:

1. Click `New Build`
2. Enter a message (e.g. `x.y release`)
3. Choose a commit
   - the default `HEAD` is usually fine
4. Choose a version branch with the pattern `x.y`
   - Builds will only run from a versioned branch, you cannot build from `main`
5. Click `Create Build`
6. Wait a minute for the Buildkite configuration to be loaded
   - When it has loaded, a `Build Information` button will appear
7. Enter the build information
8. Wait for the build to finish
