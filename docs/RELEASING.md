# Releasing

This doc is a reference for Elastic employees.
Non-Elastic users can not publish a release.

The version scheme we use is **MAJOR.MINOR.PATCH** and stored in the [product_version](../product_version) file at the root of this repository.
Open Crawler follows its own release versioning and does not follow the Elastic stack unified release schedule or versioning.

## How to publish a Docker image

Releasing is done entirely through Buildkite.
The Open Crawler build job is named `crawler-docker-build-publish`.

Build steps in buildkite:

1. Go to the [Buildkite job for publishing Crawler](https://buildkite.com/elastic/crawler-docker-build-publish)
2. Click `New Build`
3. Enter a message (e.g. `x.y release`)
4. Choose a version branch with the pattern `x.y`
    - Building from `main` is possible, but it will yield a _snapshot_ build.
    - For example, if the version inside the `product_version` file is `0.3.0`, then a build triggered from `main` will result in `0.3.0-SNAPSHOT` images.
5. Choose a commit
   - The default `HEAD` is usually fine
6. Click `Create Build`
7. Wait a minute for the Buildkite configuration to be loaded
   - When it has loaded, a `Build Information` button will appear
8. Select whether or not the build should have a `:latest` tag
9. Wait for the build to finish

Creating a release in GitHub

1. Go to https://github.com/elastic/crawler/releases
2. Click `Draft new release`
3. Create a tag for this release, following the pattern `v{major}.{minor}.{patch}`
4. Choose the target branch, this should match the `{major}.{minor}` of the tag
5. Click `Generate release notes`, this should autofill all changes 
6. If this is the latest release, make sure `Set as latest release` is selected
7. Click `Publish release`
