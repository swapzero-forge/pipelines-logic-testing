#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

PREREQS_DIR="${COMPONENT_PATH}/tests/runner/prereqs"
FIXTURES_DIR="${COMPONENT_PATH}/tests/runner/fixtures"

# Opaque app IDs per role within this transaction
PREREQS_APP_ID="${TX_ID}-prereqs"
TARGET_APP_ID="${TX_ID}-target"
FIXTURES_APP_ID="${TX_ID}-fixtures"

PLUGIN_ROOT="${SCRIPT_DIR}/plugins"

# Load all plugins once
source "${PLUGIN_ROOT}/kustomize.bash"
source "${PLUGIN_ROOT}/kustomize-helm.bash"

# Deploy prereq resources from REF (type=prereqs)
TYPE="prereqs"
APP_ID="${PREREQS_APP_ID}"
export TYPE APP_ID

if [[ -d "${PREREQS_DIR}" ]] ; then
  kustomize_deploy "${REF}" "${PREREQS_DIR}"
fi

# Deploy target workload baseline and PR revision (type=target)
TYPE="target"
APP_ID="${TARGET_APP_ID}"
export TYPE APP_ID

kustomize_helm_deploy "${BASE_REF}" "${COMPONENT_PATH}"
kustomize_helm_deploy "${REF}"      "${COMPONENT_PATH}"

# Deploy fixture resources from REF (type=fixtures)
TYPE="fixtures"
APP_ID="${FIXTURES_APP_ID}"
export TYPE APP_ID

if [[ -d "${FIXTURES_DIR}" ]] ; then
  kustomize_deploy "${REF}" "${FIXTURES_DIR}"
fi
