#!/bin/sh
#
# Turn the local host into an EPFL-STI provisioning server.
#
# Requirements: docker, bridge-utils
#
# Usage:
#   wget -O /tmp/install-provisioning-server.sh https://raw.githubusercontent.com/epfl-sti/cluster.foreman/master/install-provisioning-server.sh | sudo bash
#
# This script doesn't take flags, but its behavior can be changed using
# environment variables, e.g. replace the final "| sudo bash" with something
# along the lines of
#
#   | sudo env EPFLSTI_CLUSTER_SOURCE_DIR=/somewhere/else bash

for tool in docker brctl grep perl; do
    which "$tool" >/dev/null || {
        echo >&2 "Please install $tool and try again."
        exit 1
    }
done

docker ps >/dev/null || {
    echo >&2 "Docker doesn't look like it is configured properly (cannot"
    echo >&2 "  run \"docker ps\")."
    echo >&2 "Please fix and try again."
    exit 1
}

set -e -x

: ${EPFLSTI_CLUSTER_GITHUB_DEPOT:=epfl-sti/cluster.foreman}
: ${EPFLSTI_CLUSTER_SOURCE_DIR:=/opt/src}
: ${EPFLSTI_CLUSTER_GIT_CHECKOUT_DIR:=${EPFLSTI_CLUSTER_SOURCE_DIR}/cluster.foreman}


# Check out sources
test -d "${EPFLSTI_CLUSTER_GIT_CHECKOUT_DIR}"/.git || (
    mkdir -p "$(dirname "${EPFLSTI_CLUSTER_GIT_CHECKOUT_DIR}")"
    cd "$(dirname "${EPFLSTI_CLUSTER_GIT_CHECKOUT_DIR}")"
    git clone https://github.com/${EPFLSTI_CLUSTER_GITHUB_DEPOT}.git \
        "$(basename "${EPFLSTI_CLUSTER_GIT_CHECKOUT_DIR}")"
)
cd "${EPFLSTI_CLUSTER_GIT_CHECKOUT_DIR}"
git pull || true
test -d docker/foreman-base/pipework || \
  (cd docker; git clone https://github.com/jpetazzo/pipework.git)
(cd docker/foreman-base/pipework; git pull || true)
chmod +x docker/foreman-base/pipework/pipework

"${EPFLSTI_CLUSTER_GIT_CHECKOUT_DIR}"/configure.pl --target-file foreman-installer-answers.yaml
getyaml() {
    (set +x
    perl -Mlib="${EPFLSTI_CLUSTER_GIT_CHECKOUT_DIR}/lib" \
         -MYAML::Tiny -e 'my $struct = YAML::Tiny->read($ARGV[0])->[0]; for(split m/::/, $ARGV[1]) {$struct = $struct->{$_}}; print $struct, "\n"' \
         docker-foreman/foreman-installer-answers.yaml "$1"
    )
}

# Set up bridging so that the Dockerized Foreman may have its own IP address.
: ${EPFLSTI_INTERNAL_DOCKER_BRIDGE:=br.4priv}
iface_orig="$(getyaml foreman_provisioning::interface)"
ipaddr="$(getyaml epflsti::configure_answers::private_ip_address)"
netmask="$(getyaml foreman_provisioning::netmask)"
if ip addr show dev "${EPFLSTI_INTERNAL_DOCKER_BRIDGE}" >/dev/null 2>&1; then
    (set +x
    echo >&2 "It looks like the bridge ${EPFLSTI_INTERNAL_DOCKER_BRIDGE} was configured already."
    echo >&2 "If this is not the case, please delete the bridge and try again:"
    echo >&2
    echo >&2 "  brctl delbr ${EPFLSTI_INTERNAL_DOCKER_BRIDGE}"
    echo >&2
    )
else
    echo >&2 "Configuring bridge ${EPFLSTI_INTERNAL_DOCKER_BRIDGE}"
    brctl addbr "${EPFLSTI_INTERNAL_DOCKER_BRIDGE}"
    brctl addif "${EPFLSTI_INTERNAL_DOCKER_BRIDGE}" "$iface_orig"
    ip addr del "$ipaddr"/"$netmask" dev "$iface_orig"
    if ! ip addr show "${EPFLSTI_INTERNAL_DOCKER_BRIDGE}" 2>/dev/null | grep -q "$ipaddr"; then
        ip addr add "$ipaddr" dev "${EPFLSTI_INTERNAL_DOCKER_BRIDGE}"
    fi
fi

./configure.pl
./docker/dockerer plan
# TODO: have configure.pl pick a domain name, and use that for dockerer build and dockerer run.

# TODO: set up puppet on the head node.
