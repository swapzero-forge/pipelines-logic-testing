ARG TERRAFORM_VERSION=1.14
ARG ARGOCD_CLI_VERSION=v3.2.12
ARG KUBECTL_VERSION=v1.34.2
ARG VAULT_VERSION=1.21.0
ARG HELM_VERSION=4

# Use a multi-stage build to fetch the ArgoCD CLI binary from the official image
FROM quay.io/argoproj/argocd:${ARGOCD_CLI_VERSION} AS argocd-cli

# Hashicorp packages have been removed from alpine's repository due to Hashicorp's license changes
FROM hashicorp/vault:${VAULT_VERSION} AS vault

# kubectl image
FROM registry.k8s.io/kubectl:${KUBECTL_VERSION} AS kubectl

# Helm image
FROM alpine/helm:${HELM_VERSION} AS helm

# The main image
FROM hashicorp/terraform:${TERRAFORM_VERSION}

# Copy argocd, vault, kubectl and helm binaries
COPY --from=argocd-cli /usr/local/bin/argocd /usr/bin/argocd
COPY --from=vault /bin/vault /bin/vault
COPY --from=kubectl /bin/kubectl /bin/kubectl
COPY --from=helm /usr/bin/helm /usr/bin/helm

RUN apk update && apk add --no-cache \
    tar \
    libcap \
    bash \
    findutils \
    curl \
    openssl \
    postgresql \
    py3-pip \
    py3-json-logger \
    py3-kubernetes \
    py3-boto3 \
    aws-cli	\
    jq \
    gpg \
    gpg-agent \
    envsubst \
    colordiff && \
    setcap cap_ipc_lock= /bin/vault

RUN apk add --no-cache --virtual build-azure-cli gcc musl-dev linux-headers python3-dev && \
    python3 -m venv /opt/azure-cli && \
    . /opt/azure-cli/bin/activate && \
    pip install --no-cache-dir --no-compile azure-cli && \
    ln -s /opt/azure-cli/bin/az /usr/bin/ && \
    apk del --purge build-azure-cli

