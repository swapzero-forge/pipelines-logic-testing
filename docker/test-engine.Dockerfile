ARG ARGOCD_CLI_VERSION=v2.14.8
ARG KUBECTL_VERSION=v1.34.2
ARG HELM_VERSION=4

FROM quay.io/argoproj/argocd:${ARGOCD_CLI_VERSION} AS argocd-cli

FROM registry.k8s.io/kubectl:${KUBECTL_VERSION} AS kubectl

FROM alpine/helm:${HELM_VERSION} AS helm

FROM alpine:3.23

ENV PATH="/opt/test-engine/bin:$PATH" \
    HELM_PLUGINS="/opt/helm"

COPY --from=argocd-cli /usr/local/bin/argocd /usr/bin/argocd
COPY --from=kubectl /bin/kubectl /bin/kubectl
COPY --from=helm /usr/bin/helm /usr/bin/helm

RUN apk --no-cache add \
    curl \
    bash \
    envsubst \
    yq \
    jq \
    aws-cli \
    bats \
    bind-tools \
    github-cli \
    uuidgen

# Bake test engine framework into the container
RUN mkdir -p /opt/test-engine /opt/helm
COPY test-engine /opt/test-engine
RUN chmod +x /opt/test-engine/framework/*.sh /opt/test-engine/framework/plugins/*.bash /opt/test-engine/bin/*

USER 1001:1001
