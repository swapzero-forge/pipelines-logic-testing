#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ENGINE_TMP_DIR:
# - ${{ runner.temp }} cannot be used directly in job.env, and when passed via
#   container.env it points to a host path that does not exist inside the
#   container filesystem.
# - At runtime, GitHub injects RUNNER_TEMP (a temp dir inside the container),
#   so we prefer that when present and otherwise fall back to TMPDIR.
ENGINE_TMP_DIR=${RUNNER_TEMP:-$TMPDIR}
export ENGINE_TMP_DIR

#   PR_NUMBER      - PR number
#   REF            - git ref/branch to test (e.g. renovate/some-branch)
#   BASE_REF       - base git ref/branch to use as "current" version in tests (e.g. master)
#   COMPONENT_PATH - gitops/workloads/... path for this workload
#   DESTINATION_CLUSTER        - ArgoCD destination.clusterName
#   ARGOCD_HEALTH_WAIT_TIMEOUT - timeout for argocd app wait
#   KUBECTL_WAIT_TIMEOUT       - timeout for kubectl wait
#   ENGINE_TMP_DIR             - base directory for engine temp files
#   ARGOCD_SERVER              - ArgoCD server URL
#   ARGOCD_OPTS                - extra ArgoCD CLI options (e.g. --grpc-web)
: "${PR_NUMBER:?PR_NUMBER is required}"
: "${REF:?REF is required}"
: "${BASE_REF:?BASE_REF is required}"
: "${COMPONENT_PATH:?COMPONENT_PATH is required}"
: "${DESTINATION_CLUSTER:?DESTINATION_CLUSTER is required}"
: "${ARGOCD_HEALTH_WAIT_TIMEOUT:?ARGOCD_HEALTH_WAIT_TIMEOUT is required}"
: "${KUBECTL_WAIT_TIMEOUT:?KUBECTL_WAIT_TIMEOUT is required}"
: "${ENGINE_TMP_DIR:?ENGINE_TMP_DIR is required}"
: "${ARGOCD_SERVER:?ARGOCD_SERVER is required}"
: "${ARGOCD_OPTS:?ARGOCD_OPTS is required}"

echo "=== Test engine config ==="
echo "BASE_REF=${BASE_REF}"
echo "DESTINATION_CLUSTER=${DESTINATION_CLUSTER}"
echo "ARGOCD_HEALTH_WAIT_TIMEOUT=${ARGOCD_HEALTH_WAIT_TIMEOUT}"
echo "KUBECTL_WAIT_TIMEOUT=${KUBECTL_WAIT_TIMEOUT}"
echo "ENGINE_TMP_DIR=${ENGINE_TMP_DIR}"
echo "PR_NUMBER=${PR_NUMBER}"
echo "REF=${REF}"
echo "COMPONENT_PATH=${COMPONENT_PATH}"
echo "ARGOCD_SERVER=${ARGOCD_SERVER}"
echo "ARGOCD_OPTS=${ARGOCD_OPTS}"
echo "=========================="

echo "=== Running transaction for PR=${PR_NUMBER}, REF=${REF}, PATH=${COMPONENT_PATH} ==="

TESTS_DIR="${COMPONENT_PATH}/tests"
if [ ! -d "${TESTS_DIR}" ]; then
  echo "No tests dir at ${TESTS_DIR}, nothing to run."
  exit 0
fi

# Generate TX_ID for this transaction and export it (visible to pre.sh, plugins, post.sh)
TX_ID="tx-${PR_NUMBER}-$(date +%s)"
export TX_ID
echo "TX_ID=${TX_ID}"

SETUP_FAILED=0

# Run pre.sh to deploy prereqs/target/fixtures; record setup failure without aborting
if ! "${SCRIPT_DIR}/pre.sh"; then
  SETUP_FAILED=1
fi
export SETUP_FAILED

# Run bats tests (they self-skip if SETUP_FAILED=1) and save output under ENGINE_TMP_DIR
bats "${TESTS_DIR}/test.bats" | tee "${ENGINE_TMP_DIR}/bats-${TX_ID}.tap" || true

# Run post.sh to teardown resources associated with this TX_ID
"${SCRIPT_DIR}/post.sh"

# Report Bats results back to the PR (best-effort; do not fail the pipeline on reporting)
report-tests || true

echo "=== Done transaction for PR=${PR_NUMBER}, REF=${REF} ==="

