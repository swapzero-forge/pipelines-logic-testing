#!/bin/bash
set -e
echo "AWS Region: $AWS_DEFAULT_REGION"
echo "EKS Cluster: $CLUSTER_NAME"

aws eks --region $AWS_DEFAULT_REGION update-kubeconfig --name $CLUSTER_NAME

exec "$@"