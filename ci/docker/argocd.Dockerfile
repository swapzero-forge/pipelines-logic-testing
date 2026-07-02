ARG ARGOCD_CLI_VERSION=v3.2.12

FROM quay.io/argoproj/argocd:${ARGOCD_CLI_VERSION} AS argocd-cli

FROM alpine:3.24

COPY --from=argocd-cli /usr/local/bin/argocd /usr/bin/argocd

RUN apk add --no-cache \
    bash \
    jq \
    colordiff
