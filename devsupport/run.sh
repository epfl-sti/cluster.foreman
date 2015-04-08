#!/bin/bash
#
# Run Docker in order to test the foreman-installer process.
#
# Thanks to Docker, a mere laptop on any platform (including Mac or
# Windows) is adequate for developing and testing the Openstack-STI
# Foreman installer extensions.

set -e -x
SCRIPT_DIR="$(cd $(dirname "$0") && pwd)"
GIT_TOPDIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Build a container from the Dockerfile
docker build -t epflsti/foreman-test-install \
       $SCRIPT_DIR/docker-foreman-installer

# Run an interactive shell within a Docker container
# To run from a different tag (created e.g. with "docker commit"), say
# DOCKER_TAG=mytag devsupport/run.sh
docker run \
    -v "$GIT_TOPDIR":/opt/src/epfl.openstack-sti.foreman \
    -h ostest0.epfl.ch \
    -it epflsti/foreman-test-install:${DOCKER_TAG:-latest} /bin/bash
