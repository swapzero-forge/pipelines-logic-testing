# Image builds

This directory contains the Docker images used across various pipelines. Each image is purpose-built
for a specific job - we avoid fat catch-all images because downloading and unpacking unused tools
slows down job execution with no benefit.

Historically, any change in this directory triggered a full matrix build of all images regardless
of what actually changed. That meant unnecessary jobs running and all images being pushed to Harbor,
leaving stale temporary tags to be cleaned up by repo policies.

Now only the images with actual changes are built. A GitHub action detects which files changed,
then a simple script selects the Dockerfiles that need to be rebuilt - either because the Dockerfile
itself changed, or because a support file it references changed.

## Configuration

Image build config has been moved out of the pipeline and into `builds.yaml` in this directory.

## Adding a new image

Add an entry to `builds.yaml` following the existing pattern, then add the Dockerfile and any
support files alongside it. Open a PR - only your new image will be built.

## Constraints

The build detection logic searches for files matching `*.Dockerfile`. The `builds.yaml` lets you
specify any dockerfile name, but stick to the `name.Dockerfile` pattern so the detection works
correctly.
