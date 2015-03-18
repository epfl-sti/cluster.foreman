#!/bin/bash

set -e -x

# Build the docker
docker build -t epflsti/foreman . 

# Run the Dockerfile
SCRIPT_DIR="$(cd $(dirname "$0") && cd .. && pwd)"
docker run \
    -v "$SCRIPT_DIR":/opt/src/epfl.openstack-sti.foreman \
    -h ostest0.epfl.ch \
    -it epflsti/foreman /bin/bash
