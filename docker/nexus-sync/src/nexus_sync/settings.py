"""Runtime configuration loaded from environment variables."""
import logging
import os

NEXUS_URL = os.environ.get("NEXUS_URL", "").rstrip("/")
NEXUS_PASSWORD = os.environ.get("NEXUS_PASSWORD", "")
NEXUS_S3_BUCKET = os.environ.get("NEXUS_S3_BUCKET", "")
NEXUS_S3_REGION = os.environ.get("NEXUS_S3_REGION", "")
REPOSITORIES_CONFIG_PATH = os.environ.get("NEXUS_REPOSITORIES_CONFIG", "")
# Nexus REST API v1 paths
ENDPOINTS = {
    "eula": "/v1/system/eula",
    "anonymous": "/v1/security/anonymous",
    "blobstores": "/v1/blobstores",
    "blobstores_s3": "/v1/blobstores/s3",
    "repositories": "/v1/repositories",
    "repositories_docker_proxy": "/v1/repositories/docker/proxy",
    "repositories_docker_group": "/v1/repositories/docker/group",
}
TIMEOUT = int(os.environ.get("NEXUS_API_TIMEOUT", "10"))
DOCKER_GROUP_NAME = os.environ.get("NEXUS_DOCKER_GROUP_NAME", "cache")


def configure_logging():
    logging.basicConfig(
        level=os.environ.get("LOG_LEVEL", "INFO").upper(),
        format="%(asctime)s %(levelname)s %(message)s",
    )


def api_url(path):
    return f"{NEXUS_URL}/service/rest{path}"


def validate_required_env():
    logger = logging.getLogger(__name__)
    missing = []
    if not NEXUS_URL:
        missing.append("NEXUS_URL")
    if not NEXUS_PASSWORD:
        missing.append("NEXUS_PASSWORD")
    if not NEXUS_S3_BUCKET:
        missing.append("NEXUS_S3_BUCKET")
    if not NEXUS_S3_REGION:
        missing.append("NEXUS_S3_REGION")
    if not REPOSITORIES_CONFIG_PATH:
        missing.append("NEXUS_REPOSITORIES_CONFIG")

    if missing:
        logger.error("Missing required environment variables: %s", ", ".join(missing))
        raise SystemExit(1)

    logger.info("Startup config OK")
