"""Low-level Nexus REST API calls; all operations are idempotent (GET-before-write)."""
import logging

import requests

from .settings import NEXUS_S3_BUCKET, NEXUS_S3_REGION, TIMEOUT

logger = logging.getLogger(__name__)


def fetch_nexus_repositories(auth, repositories_url):
    logger.info("Fetching repositories from Nexus")
    resp = requests.get(repositories_url, auth=auth, timeout=TIMEOUT)
    resp.raise_for_status()
    return resp.json()


def ensure_docker_group(
    auth,
    docker_groups_url,
    group_name,
    member_names,
    payload_builder,
):
    request_body = payload_builder.build(group_name, member_names)
    docker_group_url = f"{docker_groups_url}/{group_name}"

    try:
        state_resp = requests.get(docker_group_url, auth=auth, timeout=TIMEOUT)
        state_resp.raise_for_status()
    except requests.HTTPError as exc:
        if exc.response.status_code == 404:
            # group does not exist yet, create it
            logger.warning("Docker group '%s': Does not exist, creating", group_name)
            create_resp = requests.post(docker_groups_url, auth=auth, json=request_body, timeout=TIMEOUT)
            create_resp.raise_for_status()
            logger.info("Docker group '%s': created", group_name)
            return

        logger.error("Docker group '%s': lookup failed (HTTP %s)", group_name, exc.response.status_code)
        raise

    existing_group = state_resp.json()
    current_member_names = existing_group.get("group", {}).get("memberNames", [])
    if set(current_member_names) == set(member_names):
        logger.info("Docker group '%s': unchanged", group_name)
        return

    update_resp = requests.put(docker_group_url, auth=auth, json=request_body, timeout=TIMEOUT)
    update_resp.raise_for_status()
    logger.info("Docker group '%s': updated", group_name)


def ensure_s3_blob_store_exists(auth, blobstores_url, blobstores_s3_url):
    logger.info("Checking S3 blob store status")
    state_resp = requests.get(blobstores_url, auth=auth, timeout=TIMEOUT)
    state_resp.raise_for_status()
    state_data = state_resp.json()

    if any(item["name"] == "s3" for item in state_data):
        logger.info("S3 blob store already exists")
        return

    logger.info("Creating S3 blob store")
    # blobstore name "s3" must match the name referenced by all repository configs
    request_body = {
        "name": "s3",
        "bucketConfiguration": {
            "bucket": {
                "name": NEXUS_S3_BUCKET,
                "region": NEXUS_S3_REGION,
                "expiration": 0,
            }
        },
    }
    update_resp = requests.post(blobstores_s3_url, auth=auth, json=request_body, timeout=TIMEOUT)
    update_resp.raise_for_status()
    logger.info("S3 blob store created")


def ensure_eula_accepted(auth, eula_url):
    logger.info("Checking EULA status")
    state_resp = requests.get(eula_url, auth=auth, timeout=TIMEOUT)
    state_resp.raise_for_status()
    state_data = state_resp.json()

    if state_data.get("accepted") is True:
        logger.info("EULA already accepted")
        return

    logger.info("Accepting EULA")
    request_body = {
        "accepted": True,
        "disclaimer": state_data["disclaimer"],
    }
    update_resp = requests.post(eula_url, auth=auth, json=request_body, timeout=TIMEOUT)
    update_resp.raise_for_status()
    logger.info("EULA accepted")


def ensure_anonymous_enabled(auth, anonymous_url):
    logger.info("Checking anonymous access status")
    state_resp = requests.get(anonymous_url, auth=auth, timeout=TIMEOUT)
    state_resp.raise_for_status()
    state_data = state_resp.json()

    if state_data.get("enabled") is True:
        logger.info("Anonymous access already enabled")
        return

    logger.info("Enabling anonymous access")
    request_body = {
        "enabled": True,
        "userId": state_data.get("userId", "anonymous"),
        "realmName": state_data.get("realmName", "NexusAuthorizingRealm"),
    }
    update_resp = requests.put(anonymous_url, auth=auth, json=request_body, timeout=TIMEOUT)
    update_resp.raise_for_status()
    logger.info("Anonymous access enabled")


def create_repository(auth, repositories_create_url, repository, payload_builder):
    request_body = payload_builder.build(repository["name"], repository["remoteUrl"], repository["indexType"])
    create_resp = requests.post(repositories_create_url, auth=auth, json=request_body, timeout=TIMEOUT)
    create_resp.raise_for_status()
    logger.info("Created repository '%s'", repository["name"])
