# Test Engine Overview

This directory contains the **test engine** that is baked into the
`docker.navvis.com/infra/test-engine` image.

The engine is responsible for:
- Selecting which PRs/workloads to test via a PR selector (`select-tests`).
- Preparing a target environment (using `pre.sh`, plugins, and generators).
- Running Bats tests for a given component/workload.
- Collecting test output into `ENGINE_TMP_DIR`.
- Translating Bats TAP output into Markdown and posting it as a comment in the
  tested PR.

## Components

- `bin/select-tests`  
  - Acts as a **PR selector**: inspects Renovate PRs and repository state.
  - Produces a **JSON matrix** describing which PRs / workloads to test
    (PR number, refs, component paths, etc.).
  - This JSON is consumed by a GitHub Actions **matrix job** that is configured
    to run all entries **sequentially**; for each matrix entry, the test engine
    runner is invoked.

- `framework/runner.sh`  
  - Runs once per matrix entry (per PR/workload).
  - Reads configuration from environment variables (PR ref, base ref, component
    path, cluster, timeouts, etc.).
  - Derives a transaction ID (`TX_ID`) for the current run.
  - Executes:
    1. `pre.sh` – deploys prerequisites and the target under test.
    2. Bats tests under `${COMPONENT_PATH}/tests`, writing TAP to `ENGINE_TMP_DIR`.
    3. `post.sh` – tears everything down.
    4. `report-tests` – converts the TAP file to Markdown and reports it as a
       comment on the corresponding PR.

Temporary data and Bats output are written under `ENGINE_TMP_DIR` inside the
container.

## Why bake the engine into the container?

The engine is bundled inside the image so that:

- Any repository can reuse the same engine by just using the image.
- Workflows stay small and only need to provide environment variables, not copy
  shell scripts or engine logic around.

If the engine lived only in the repository (and the container was just a tools
image), the full logic would only be runnable from that particular repo, or
you would need extra mechanisms (like Git submodules or additional checkouts /
mounts) to share it. Those approaches work, but they add complexity in CI and
repo management.

By baking the engine into the container, the behavior is consistent and easily
reused across multiple repositories.

> Note: In its current form, the engine is more suited for **CI runs** than for
> local usage. The design may evolve in the future to make local runs more
> convenient while keeping the CI behavior stable.
