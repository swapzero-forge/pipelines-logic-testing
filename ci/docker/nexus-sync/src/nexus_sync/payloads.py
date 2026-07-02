"""Request body builders for the Nexus REST API."""


class DockerProxyPayloadBuilder:
    def __init__(self, blob_store_name="s3"):
        self.blob_store_name = blob_store_name

    def build(self, name, remote_url, index_type):
        # index_type controls how Nexus searches for images:
        # "HUB" queries the Docker Hub search API; "REGISTRY" queries the registry's own v2 catalog
        return {
            "name": name,
            "online": True,
            "storage": {
                "blobStoreName": self.blob_store_name,
                "strictContentTypeValidation": True,
                "writePolicy": "ALLOW",
            },
            "docker": {
                "v1Enabled": False,
                "forceBasicAuth": False,
                "pathEnabled": True,
            },
            "dockerProxy": {
                "indexType": index_type,
                "cacheForeignLayers": False,
                "foreignLayerUrlWhitelist": [],
            },
            "proxy": {
                "remoteUrl": remote_url,
                "contentMaxAge": 1440,
                "metadataMaxAge": 1440,
            },
            "negativeCache": {
                "enabled": True,
                "timeToLive": 1440,
            },
            "httpClient": {
                "blocked": False,
                "autoBlock": True,
                "connection": {
                    "enableCircularRedirects": False,
                    "enableCookies": False,
                    "useTrustStore": False,
                },
            },
        }


class DockerGroupPayloadBuilder:
    def __init__(self, blob_store_name="s3"):
        self.blob_store_name = blob_store_name

    def build(self, name, member_names):
        return {
            "name": name,
            "online": True,
            "storage": {
                "blobStoreName": self.blob_store_name,
                "strictContentTypeValidation": True,
            },
            "group": {
                "memberNames": member_names,
            },
            "docker": {
                "v1Enabled": False,
                "forceBasicAuth": False,
                "pathEnabled": True,
            },
        }
