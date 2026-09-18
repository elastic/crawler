# Releasing

## Version scheme

`MAJOR.MINOR.PATCH` stored in the `product_version` file. Independent of the Elastic stack release schedule.

**Branch model:**
- `main` — next minor/major development line (e.g. `1.1.0`). Builds always produce `-SNAPSHOT` images.
- `N.N` branch (e.g. `1.0`) — maintenance branch for that minor line. Patch releases (`1.0.1`, `1.0.2`, …) are cut from here.

## Cutting a release

### 1. Docker image (via Buildkite)

Trigger the **crawler-docker-build-publish** pipeline manually:

1. Select the `N.N` branch (e.g. `1.0`) — **not** `main`.
2. Set **Build type** to **Release**. (Default is Snapshot — the pipeline will reject Release builds from `main`.)
3. Set **Apply :latest tag** to **Yes** only for the newest GA release.
4. The pipeline reads `product_version` from the branch to determine the image tag.

### 2. GitHub release tag

1. Create a GitHub release at `elastic/crawler/releases`.
2. Tag: `v{major}.{minor}.{patch}` (e.g. `v1.0.1`).
3. Target: the **same commit SHA** as the Buildkite build.
4. GitHub will auto-generate release notes.

Both artifacts must target the same commit.

## After a release

### After a patch release (e.g. released `1.0.1` from `1.0`)

Bump `product_version` on the `N.N` branch to the next patch:
```bash
# On a PR targeting the 1.0 branch:
echo "1.0.2" > product_version
```
No change needed on `main`.

### After a minor release (e.g. released `1.1.0`)

1. Cut the `N.N` branch from the release commit:
   ```bash
   git checkout -b 1.1 v1.1.0
   git push origin 1.1
   ```
2. Bump `product_version` on `main` to the next minor:
   ```bash
   # On a PR targeting main:
   echo "1.2.0" > product_version
   ```
3. Add `"1.1"` to `targetBranchChoices` in `.backportrc.json`.

## Snapshot builds

Triggering the pipeline with the default "Snapshot" build type produces a
`<version>-SNAPSHOT` image. This is safe to do from any branch at any time.

## Internal runbook

Full step-by-step: `search-team/teams/agent-builder/agent-builder-1/crawler/releasing-new-crawler-versions` in the internal team docs.
