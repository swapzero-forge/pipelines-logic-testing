#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/log.bash"

LOG_PREFIX="kustomize-helm"

# Deploys a Helm-based workload via ArgoCD using Helm chart configuration
# extracted from the workload's kustomization.yaml (helmCharts[0]).
#
# Types are set by pre.sh (target) via the TYPE/APP_ID env vars.
#
# Args:
#   $1: Git reference (e.g., master, renovate/some-branch)
#   $2: Path to workload directory in gitops repo (contains kustomization.yaml)
kustomize_helm_deploy() {
  local GIT_REF="$1"
  local GITOPS_PATH="$2"

  log "INFO" "$FUNCNAME" "=== DEPLOYMENT START === type=${TYPE:-unknown} app_id=${APP_ID:-unknown}"
  log "INFO" "$FUNCNAME" "ref=${GIT_REF} path=${GITOPS_PATH}"

  # yq needs this exported to access via env(GIT_REF)
  export GIT_REF

  log "INFO" "$FUNCNAME" "Starting deployment from ${GIT_REF} (path: ${GITOPS_PATH})"

  local VALUES_FILE="${ENGINE_TMP_DIR}/${TX_ID}-${TYPE}-values.yaml"
  local APPLICATION_FILE="${ENGINE_TMP_DIR}/${TX_ID}-${TYPE}-application.yaml"

  # Extract Helm chart configuration from kustomization
  git show "origin/${GIT_REF}:${GITOPS_PATH}/kustomization.yaml" \
    | yq '
      .helmCharts[0]
      | {
        "helm": {
          "repoURL": .repo,
          "chart": .name,
          "version": .version,
          "releaseName": .releaseName,
          "namespace": .namespace,
          "valueFiles": [.valuesFile] + .additionalValuesFiles
        },
        "valuesSource": { "targetRevision": env(GIT_REF)}
      }
    ' > "${VALUES_FILE}"

  # Parse extracted values
  local NAMESPACE
  local RELEASE_NAME
  local CHART_VERSION

  NAMESPACE=$(yq '.helm.namespace' "${VALUES_FILE}")
  RELEASE_NAME=$(yq '.helm.releaseName' "${VALUES_FILE}")
  CHART_VERSION=$(yq '.helm.version' "${VALUES_FILE}")
  local ARGOCD_APP_NAME="${APP_ID}"

  log "INFO" "$FUNCNAME" "Deploying '${ARGOCD_APP_NAME}' v${CHART_VERSION} to namespace '${NAMESPACE}'"

  # Generate ArgoCD Application manifest (chart is under ../generators/kustomize-helm)
  local CHART_DIR="${SCRIPT_DIR}/../generators/kustomize-helm"

  helm template "$ARGOCD_APP_NAME" "${CHART_DIR}" \
    --set destination.clusterName="${DESTINATION_CLUSTER}" \
    --set gitopsPath="$GITOPS_PATH" \
    --set gitRef="$GIT_REF" \
    --values "${VALUES_FILE}" > "${APPLICATION_FILE}"

  # Create or update ArgoCD application
  argocd app create -f "${APPLICATION_FILE}" --upsert \
    --label "ownerId=${TX_ID}" \
    --label "type=${TYPE}" \
    && sleep 1

  # Sync the application (autosync is disabled by default)
  argocd app sync "$ARGOCD_APP_NAME" --async && sleep 1

  # Wait for sync and health checks to complete
  log "INFO" "$FUNCNAME" "Waiting for app '${ARGOCD_APP_NAME}' to become healthy"
  argocd app wait -l "ownerId=${TX_ID},type=${TYPE}" --operation --timeout "${ARGOCD_HEALTH_WAIT_TIMEOUT}" >/dev/null
  argocd app wait -l "ownerId=${TX_ID},type=${TYPE}" --health --sync --timeout "${ARGOCD_HEALTH_WAIT_TIMEOUT}" >/dev/null

  # Wait for deployment to be available in Kubernetes
  log "INFO" "$FUNCNAME" "Checking deployment status for '${RELEASE_NAME}'"
  kubectl rollout status statefulset,deployment -n "$NAMESPACE" --timeout="${KUBECTL_WAIT_TIMEOUT}"

  log "INFO" "$FUNCNAME" "Successfully deployed '${RELEASE_NAME}' v${CHART_VERSION} to '${NAMESPACE}'"
  log "INFO" "$FUNCNAME" "=== DEPLOYMENT COMPLETE === type=${TYPE:-unknown} app_id=${APP_ID:-unknown}"
}
