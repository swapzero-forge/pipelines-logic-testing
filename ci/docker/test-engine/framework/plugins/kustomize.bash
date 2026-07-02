#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/log.bash"

LOG_PREFIX="kustomize"

# Deploys a kustomization-based workload via ArgoCD for a given type.
#
# Types are set by pre.sh (prereqs/target/fixtures) via the TYPE/APP_ID env vars.
#
# Args:
#   $1: Git reference (e.g., master, renovate/some-branch)
#   $2: Path to workload directory in gitops repo (contains kustomization.yaml)
kustomize_deploy() {
  local GIT_REF="${1}"
  local GITOPS_PATH="${2}"

  log "INFO" "$FUNCNAME" "=== DEPLOYMENT START === type=${TYPE:-unknown} app_id=${APP_ID:-unknown}"
  log "INFO" "$FUNCNAME" "ref=${GIT_REF} path=${GITOPS_PATH}"

  log "INFO" "$FUNCNAME" "Starting deployment from ${GIT_REF} (path: ${GITOPS_PATH})"

  # App name is provided by caller via APP_ID
  local ARGOCD_APP_NAME="${APP_ID}"

  log "INFO" "$FUNCNAME" "Deploying '${ARGOCD_APP_NAME}' revision '${GIT_REF}'"

  # Generate ArgoCD Application manifest (chart is under ../generators/kustomize)
  local CHART_DIR="${SCRIPT_DIR}/../generators/kustomize"
  local APPLICATION_FILE="${ENGINE_TMP_DIR}/${TX_ID}-${TYPE}-application.yaml"

  helm template "$ARGOCD_APP_NAME" "${CHART_DIR}" \
    --set destination.clusterName="${DESTINATION_CLUSTER}" \
    --set gitopsPath="$GITOPS_PATH" \
    --set gitRef="$GIT_REF" > "${APPLICATION_FILE}"

  # Create or update ArgoCD application; ownerId and type are provided by caller
  argocd app create -f "${APPLICATION_FILE}" --upsert \
    --label "ownerId=${TX_ID}" \
    --label "type=${TYPE}"

  # Sync the application (autosync is disabled by default)
  argocd app sync $ARGOCD_APP_NAME --async && sleep 1

  # Wait for operation and health checks to complete
  log "INFO" "$FUNCNAME" "Waiting for app '${ARGOCD_APP_NAME}' to become healthy"
  argocd app wait -l "ownerId=${TX_ID},type=${TYPE}" --health --operation --timeout "${ARGOCD_HEALTH_WAIT_TIMEOUT}" >/dev/null

  log "INFO" "$FUNCNAME" "Successfully deployed '${GIT_REF}', (path: ${GITOPS_PATH})"
  log "INFO" "$FUNCNAME" "=== DEPLOYMENT COMPLETE === type=${TYPE:-unknown} app_id=${APP_ID:-unknown}"
}
