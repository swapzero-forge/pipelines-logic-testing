#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   TX_ID must be exported in the environment.
#
# Deletes all Argo CD applications belonging to a given transaction,
# using labels:
#   ownerId=${TX_ID}
#   type=prereqs|target|fixtures
#
# Order: fixtures -> target -> prereqs
# All deletes are best-effort and never fail the script.

# fixtures
argocd app delete -l "ownerId=${TX_ID},type=fixtures" --yes --wait || true

# target
argocd app delete -l "ownerId=${TX_ID},type=target" --yes --wait || true

# prereqs
argocd app delete -l "ownerId=${TX_ID},type=prereqs" --yes --wait || true
