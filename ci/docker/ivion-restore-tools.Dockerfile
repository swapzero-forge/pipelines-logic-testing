FROM quay.io/argoproj/argocd:v3.2.12 AS argocd-tools
FROM registry.k8s.io/kubectl:v1.36.1 AS kubectl

# renovate: datasource=docker depName=python
FROM python:3.14-alpine

COPY --from=argocd-tools /usr/local/bin/argocd /usr/local/bin/argocd
COPY --from=kubectl /bin/kubectl /usr/local/bin/kubectl

RUN apk add --no-cache \
    jq \
    bash \
    aws-cli \
    git \
    postgresql17-client

COPY ivion-restore-tools/requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r /tmp/requirements.txt && \
    rm /tmp/requirements.txt

COPY ivion-restore-tools/create-rds-pitr /usr/local/bin/create-rds-pitr
COPY ivion-restore-tools/teardown-rds-pitr /usr/local/bin/teardown-rds-pitr
COPY ivion-restore-tools/dump-from-pitr-rds /usr/local/bin/dump-from-pitr-rds
COPY ivion-restore-tools/restore-to-live-rds /usr/local/bin/restore-to-live-rds
COPY ivion-restore-tools/clumio-prefix-restore /usr/local/bin/clumio-prefix-restore
COPY ivion-restore-tools/clumio-validate-pitr /usr/local/bin/clumio-validate-pitr
RUN chmod +x \
    /usr/local/bin/create-rds-pitr \
    /usr/local/bin/teardown-rds-pitr \
    /usr/local/bin/dump-from-pitr-rds \
    /usr/local/bin/restore-to-live-rds \
    /usr/local/bin/clumio-prefix-restore \
    /usr/local/bin/clumio-validate-pitr

USER 1001:1001
