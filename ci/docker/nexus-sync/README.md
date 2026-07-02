# nexus-sync

Small Python package that reconciles Nexus state against a declarative YAML config. Runs as an ArgoCD PostSync hook (k8s Job), same namespace as Nexus.

## Idempotency

All operations are GET-before-write. Nothing happens if the state is already correct, so you can run the job as many times as you want.

## Limitations

- docker proxy repos - create only. If a repo already exists, it gets skipped. Updating an existing repo's config is not supported yet.
- docker group - the only thing that gets updated is the member list. If the members match what's in the config, nothing happens.

## Modules

### `nexus_api.py`

All the Nexus REST calls. Safe to re-run.

- `ensure_eula_accepted` - checks first, accepts only if needed
- `ensure_anonymous_enabled` - same pattern
- `ensure_s3_blob_store_exists` - lists blobstores, creates only if missing
- `fetch_nexus_repositories` - just a GET, returns the full list
- `create_repository` - creates a single docker proxy repo
- `ensure_docker_group` - creates or updates the group, skips if members already match

### `repositories.py`

- `load_configured_docker_proxy_repositories` - loads `repositories.docker-proxy.yaml`, applies per-repo `indexType` overrides on top of the default

### `settings.py`

All config from env vars.

### `payloads.py`

Builds the request bodies for proxy repos and the docker group. Keeps that out of the API layer.

### `workflow.py`

Entry point (`nexus-sync`). Runs in order:

1. Accept EULA
2. Enable anonymous access
3. Ensure S3 blobstore exists
4. Create any docker proxy repos not yet in Nexus
5. Ensure the `cache` group exists with the correct member list

## Env vars

| Variable | Required | Default |
|---|---|---|
| `NEXUS_URL` | yes | |
| `NEXUS_PASSWORD` | yes | |
| `NEXUS_S3_BUCKET` | yes | |
| `NEXUS_S3_REGION` | yes | |
| `NEXUS_REPOSITORIES_CONFIG` | yes | |
| `NEXUS_DOCKER_GROUP_NAME` | no | `cache` |
| `NEXUS_API_TIMEOUT` | no | `10` |
| `LOG_LEVEL` | no | `INFO` |

## Local build

```sh
# from ci/docker/
docker build -f nexus-sync.Dockerfile -t nexus-sync:local .
```

```sh
docker run --rm \
  -e NEXUS_URL=https://nexus.dev.renvc.net \
  -e NEXUS_PASSWORD=... \
  -e NEXUS_S3_BUCKET=renvc-dev-dev-nexus-blob-store \
  -e NEXUS_S3_REGION=eu-central-1 \
  -e NEXUS_REPOSITORIES_CONFIG=/config/repositories.yaml \
  -v $(pwd)/../../gitops/workloads/nexus-cache/config/repositories.docker-proxy.yaml:/config/repositories.yaml \
  nexus-sync:local
```
