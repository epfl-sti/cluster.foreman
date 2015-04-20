#!/bin/sh
#
# Turn the local host into an EPFL-STI provisioning server.
#
# Usage:
#   wget -O /tmp/install-provisioning-server.sh https://raw.githubusercontent.com/epfl-sti/cluster.foreman/master/install-provisioning-server.sh
#   sudo bash /tmp/run.sh
#
# One unfortunately *cannot* just pipe wget into bash, because
# foreman-installer wants a tty :(
#
# This script doesn't take flags, but its behavior can be changed using
# environment variables, e.g.
#
#   EPFLSTI_CLUSTER_SOURCE_DIR=/somewhere/else sudo bash /tmp/run.sh
#
# Search for EPFLSTI_CLUSTER_ for other variables that can be used in that way.
#
# Please keep this script:
#  * repeatable: it should be okay to run it twice
#  * readable (with comments in english)
#  * minimalistic: complicated things should be done with Puppet instead
#                  (see https://github.com/epfl-sti/cluster.foreman/wiki/Hacking
#                  for how to do what where)

set -e -x

: ${EPFLSTI_CLUSTER_GITHUB_DEPOT:=epfl-sti/cluster.foreman}
: ${EPFLSTI_CLUSTER_SOURCE_DIR:=/opt/src}
: ${EPFLSTI_CLUSTER_GIT_CHECKOUT_DIR:=${EPFLSTI_CLUSTER_SOURCE_DIR}/cluster.foreman}

# Check out sources
test -d "${EPFLSTI_CLUSTER_GIT_CHECKOUT_DIR}"/.git || (
    cd "$(dirname "${EPFLSTI_CLUSTER_GIT_CHECKOUT_DIR}")"
    git clone https://github.com/${EPFLSTI_CLUSTER_GITHUB_DEPOT}.git \
        "$(basename "${EPFLSTI_CLUSTER_GIT_CHECKOUT_DIR}")"
)
(cd "${EPFLSTI_CLUSTER_GIT_CHECKOUT_DIR}"; git pull || true)

which yum-config-manager || {
  yum -y install yum-utils
}

case "$(cat /etc/redhat-release)" in
  "Red Hat"*|CentOS*)
    foreman_release_url="http://yum.theforeman.org/releases/1.8/el6/x86_64/foreman-release.rpm"
    rpm -q epel-release-6-8 || \
      rpm -ivh --force https://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
    yum-config-manager --enable rhel-6-server-optional-rpms rhel-server-rhscl-6-rpms
    rpm -qa | grep puppetlabs-release || \
      rpm -ivh https://yum.puppetlabs.com/puppetlabs-release-el-6.noarch.rpm

    ;;
  *)
    echo >&2 "Unsupported OS: $(cat /etc/redhat-release)"
    exit 2
    ;;
  esac

which foreman-installer || {
    rpm -q foreman-release || yum -y install $foreman_release_url
    yum -y install foreman-installer
}

[ -n "$EPFLSTI_CLUSTER_INSTALL_PREREQS_ONLY" ] && exit 0

# Write (or update) /etc/foreman/foreman-installer-answers.yaml:
./configure.pl $EPFLSTI_CLUSTER_CONFIGURE_FLAGS
# Read same, and thus doesn't need any command-line flags; please
# keep it that way
foreman-installer

# Install our own Puppet configuration
# This should be done using foreman-installer/modules/epflsti instead
test -L /etc/puppet/environments || {
    mv --backup -T /etc/puppet/environments /etc/puppet/environments.ORIG || \
        rm -rf /etc/puppet/environments
    ln -s "${EPFLSTI_CLUSTER_GIT_CHECKOUT_DIR}"/puppet/environments \
       /etc/puppet/environments
}
