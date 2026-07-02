"""Orchestrates the full idempotent Nexus bootstrap sequence."""
import logging

from requests.auth import HTTPBasicAuth

from . import nexus_api as nexus
from . import payloads
from . import repositories as repos
from . import settings as cfg

logger = logging.getLogger(__name__)


def main():
    cfg.configure_logging()
    cfg.validate_required_env()

    auth = HTTPBasicAuth("admin", cfg.NEXUS_PASSWORD)
    docker_proxy_payload_builder = payloads.DockerProxyPayloadBuilder(blob_store_name="s3")
    docker_group_payload_builder = payloads.DockerGroupPayloadBuilder(blob_store_name="s3")

    eula_url = cfg.api_url(cfg.ENDPOINTS["eula"])
    anonymous_url = cfg.api_url(cfg.ENDPOINTS["anonymous"])
    blobstores_url = cfg.api_url(cfg.ENDPOINTS["blobstores"])
    blobstores_s3_url = cfg.api_url(cfg.ENDPOINTS["blobstores_s3"])
    repositories_url = cfg.api_url(cfg.ENDPOINTS["repositories"])
    repositories_create_url = cfg.api_url(cfg.ENDPOINTS["repositories_docker_proxy"])
    docker_groups_url = cfg.api_url(cfg.ENDPOINTS["repositories_docker_group"])

    # --- bootstrap: system-level configuration
    nexus.ensure_eula_accepted(auth, eula_url)
    nexus.ensure_anonymous_enabled(auth, anonymous_url)
    nexus.ensure_s3_blob_store_exists(auth, blobstores_url, blobstores_s3_url)

    # --- reconcile: docker proxy repositories
    config_repositories = repos.load_configured_docker_proxy_repositories(cfg.REPOSITORIES_CONFIG_PATH)
    nexus_all_repositories = nexus.fetch_nexus_repositories(auth, repositories_url)
    nexus_proxy_repo_names = {
        item["name"]
        for item in nexus_all_repositories
        if item.get("format") == "docker" and item.get("type") == "proxy"
    }

    config_repo_names = {repo["name"] for repo in config_repositories}
    if not config_repo_names:
        logger.error("No configured docker-proxy repositories; failing job")
        raise SystemExit(1)

    repositories_to_add = [
        repo for repo in config_repositories if repo["name"] not in nexus_proxy_repo_names
    ]

    if not repositories_to_add:
        logger.info("All configured repositories already exist, nothing to create")
    else:
        for repository in repositories_to_add:
            nexus.create_repository(auth, repositories_create_url, repository, docker_proxy_payload_builder)

    # --- reconcile: docker group membership
    docker_group_members = sorted(config_repo_names)
    nexus.ensure_docker_group(
        auth,
        docker_groups_url,
        cfg.DOCKER_GROUP_NAME,
        docker_group_members,
        docker_group_payload_builder,
    )

    logger.info("Done")
