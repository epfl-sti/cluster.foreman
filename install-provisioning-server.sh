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

rpm -q epel-release || yum install epel-release

case "$(cat /etc/redhat-release)" in
  "Red Hat"*"release 7"*|CentOS*"release 7"*)
      distmajor=7 ;;
  "Red Hat"*"release 6"*|CentOS*"release 6"*)
      distmajor=6 ;;
  *)
      echo >&2 "Unsupported OS: $(cat /etc/redhat-release)"
      exit 2
      ;;
esac

case "$(cat /etc/redhat-release)" in
    "Red Hat"*)
        # From the Foreman docs
        yum-config-manager --enable rhel-$distmajor-server-optional-rpms rhel-server-rhscl-$distmajor-rpms
        ;;
    CentOS*"release 7"*)
        # https://github.com/theforeman/puppet-foreman/issues/327
        yum -y install rhscl-ruby193-epel-7-x86_64
        ;;
esac

rpm -qa | grep puppetlabs-release || \
  rpm -ivh https://yum.puppetlabs.com/puppetlabs-release-el-$distmajor.noarch.rpm
yum -y install puppet  # Make sure it is up to date

foreman_release_url="http://yum.theforeman.org/releases/latest/el$distmajor/x86_64/foreman-release.rpm"

which foreman-installer || {
    rpm -q foreman-release || yum -y install $foreman_release_url
    yum -y install foreman-installer
}

[ -n "$EPFLSTI_CLUSTER_INSTALL_PREREQS_ONLY" ] && exit 0

# Write (or update) /etc/foreman/foreman-installer-answers.yaml:
./configure.pl $EPFLSTI_CLUSTER_CONFIGURE_FLAGS
# Read same, and thus not needing any command-line flags; please
# keep it that way
foreman-installer
