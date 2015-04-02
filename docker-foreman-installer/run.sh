#!/bin/bash

set -e -x
SCRIPT_DIR="$(cd $(dirname "$0") && pwd)"
GIT_TOPDIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Build the docker
docker build -t epflsti/foreman-test-install $SCRIPT_DIR

# Run the Dockerfile
docker run \
    -v "$GIT_TOPDIR":/opt/src/epfl.openstack-sti.foreman \
    -h ostest0.epfl.ch \
    -it epflsti/foreman-test-install /bin/bash
