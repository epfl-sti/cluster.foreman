#!/bin/bash
#
# Run Docker in order to test the foreman-installer process.
#
# Thanks to Docker, a mere laptop on any platform (including Mac or
# Windows) is adequate for developing and testing the EPFL-STI
# Foreman installer extensions.

set -e -x
SCRIPT_DIR="$(cd $(dirname "$0") && pwd)"
GIT_TOPDIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Build a container from the Dockerfile
docker build -t epflsti/foreman-test-install \
       $SCRIPT_DIR/docker-foreman-installer

case $(uname) in
    Linux)
        : ${FOREMAN_PORT:=8443}
        (set +x
         echo >&2 "Foreman Web UI will be available at https://localhost/${FOREMAN_PORT}"
         echo >&2
        )
        ;;
    *)
        : ${FOREMAN_PORT:=443}
        (set +x
         echo >&2 "Foreman Web UI will be available on port ${FOREMAN_PORT} of the VM's Host only IP."
         boot2docker ip
        )
        ;;
esac

# Run an interactive shell within a Docker container
# To run from a different tag (created e.g. with "docker commit"), say
# DOCKER_TAG=mytag devsupport/run.sh
docker run \
    -v "$GIT_TOPDIR":/opt/src/cluster.foreman \
    -h ostest0.cloud.epfl.ch \
    -p $FOREMAN_PORT:443 -p 69:69/udp \
    -it epflsti/foreman-test-install:${DOCKER_TAG:-latest} /bin/bash
