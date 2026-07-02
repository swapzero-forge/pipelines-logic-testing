"""Loads the declarative docker-proxy repository list from the YAML config file."""
import logging
import sys

import yaml

logger = logging.getLogger(__name__)


def load_configured_docker_proxy_repositories(path):
    logger.info("Loading configured docker-proxy repositories from %s", path)
    try:
        with open(path, encoding="utf-8") as fh:
            data = yaml.safe_load(fh) or {}

        defaults = data.get("defaults", {})

        configured_repositories = []
        for item in data.get("repositories", []):
            configured_repositories.append(
                {
                    "name": item["name"],
                    "remoteUrl": item["remoteUrl"],
                    # per-repo indexType overrides the top-level default; fallback is REGISTRY
                    "indexType": item.get("indexType") or defaults.get("indexType", "REGISTRY"),
                }
            )

    except Exception as exc:
        logger.error("Failed to load repositories config %s: %s", path, exc)
        sys.exit(1)

    return configured_repositories
