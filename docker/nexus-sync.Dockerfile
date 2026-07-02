FROM python:3.14-slim

WORKDIR /app

COPY nexus-sync-requirements.txt requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY nexus-sync/pyproject.toml .
COPY nexus-sync/src/nexus_sync/ src/nexus_sync/
RUN pip install --no-cache-dir --no-deps .

# required at runtime: NEXUS_URL, NEXUS_PASSWORD, NEXUS_S3_BUCKET, NEXUS_S3_REGION, NEXUS_REPOSITORIES_CONFIG
# optional: NEXUS_DOCKER_GROUP_NAME (default: cache), NEXUS_API_TIMEOUT (default: 10), LOG_LEVEL (default: INFO)
ENTRYPOINT ["nexus-sync"]
