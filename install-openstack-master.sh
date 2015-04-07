#!/bin/sh
#
# Turn the local host into an OpenStack-STI master.
#
# Usage:
#   wget -O /tmp/install-openstack-master.sh https://raw.githubusercontent.com/epfl-sti/epfl.openstack-sti.foreman/master/install-openstack-master.sh
#   OPENSTACK_STIIT_INTERNAL_IFACE=eth1 sudo bash /tmp/run.sh
#
# One unfortunately *cannot* just pipe wget into bash, because
# foreman-installer wants a tty :( Oh well, this means we are free
# to have configure.pl ask questions interactively.
#
# Please keep this script:
#  * repeatable: it should be okay to run it twice
#  * readable (with comments in english)
#  * minimalistic: complicated things should be done with Puppet instead

set -e -x

: ${OPENSTACK_STIIT_GITHUB_DEPOT:=epfl-sti/epfl.openstack-sti.foreman}
: ${OPENSTACK_STIIT_SOURCE_DIR:=/opt/src}
: ${OPENSTACK_STIIT_GIT_CHECKOUT_DIR:=${OPENSTACK_STIIT_SOURCE_DIR}/epfl.openstack-sti.foreman}

# Check out sources
test -d "${OPENSTACK_STIIT_GIT_CHECKOUT_DIR}"/.git || (
    cd "$(dirname "${OPENSTACK_STIIT_GIT_CHECKOUT_DIR}")"
    git clone https://github.com/${OPENSTACK_STIIT_GITHUB_DEPOT}.git \
        "$(basename "${OPENSTACK_STIIT_GIT_CHECKOUT_DIR}")"
)
(cd "${OPENSTACK_STIIT_GIT_CHECKOUT_DIR}"; git pull || true)

which yum-config-manager || {
  yum -y install yum-utils
}

case "$(cat /etc/redhat-release)" in
  "Fedora release 20"*)
    # Supported only for the Docker test; see docker-foreman/Dockerfile
    foreman_release_url="http://yum.theforeman.org/releases/1.8/f19/x86_64/foreman-release.rpm"
    rpm -qa | grep puppetlabs-release || \
      rpm -ivh https://yum.puppetlabs.com/puppetlabs-release-fedora-20.noarch.rpm
    ;;
  "Red Hat"*|CentOS*)
    foreman_release_url="http://yum.theforeman.org/releases/1.8/el6/x86_64/foreman-release.rpm"
    rpm -q epel-release-6-8 || \
      rpm -ivh --force https://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
    yum-config-manager --enable rhel-6-server-optional-rpms rhel-server-rhscl-6-rpms
    rpm -qa | grep puppetlabs-release || \
      rpm -ivh https://yum.puppetlabs.com/puppetlabs-release-el-6.noarch.rpm

    ;;
  esac

which foreman-installer || {
    rpm -q foreman-release || yum -y install $foreman_release_url
    yum -y install foreman-installer
}

# Install ruby193-rubygem-foreman_column_view if not present
which ruby193-rubygem-foreman_column_view || {
    yum -y install ruby193-rubygem-foreman_column_view || true
}
 
# Configure the foreman column view plugin
echo "# Default Openstack STI foreman cloumn view plugin configuration
# See ruby193-rubygem-foreman_column_view-doc and /opt/rh/ruby193/root/usr/share/gems/gems/foreman_column_view-0.2.0/README.md for more information
:column_view:
  :architecture:
    :title: Arch
    :after: last_report
    :content: facts_hash['architecture']
  :memorytotal:
    :title: Mem
    :after: architecture
    :content: facts_hash['memorysize']
  :comment:
    :title: Comment
    :after: last_report
    :content: comment
" > /usr/share/foreman/config/settings.plugins.d/foreman_column_view.yaml || true


if test -z "${OPENSTACK_STIIT_SKIP_FOREMAN_INSTALLER}"; then
    ./configure.pl
    test -L /usr/share/foreman-installer/modules/openstacksti || \
      ln -sf "${OPENSTACK_STIIT_GIT_CHECKOUT_DIR}"/foreman-installer/modules/openstacksti \
         /usr/share/foreman-installer/modules/openstacksti
    foreman-installer \
        --enable-foreman-proxy \
        --foreman-proxy-tftp=true \
        --foreman-proxy-dhcp=true \
        --foreman-proxy-dns=true \
        --foreman-proxy-bmc=true \
        --foreman-proxy-bmc-default-provider=ipmitool
fi

# Install our own Puppet configuration
# This should be done using foreman-installer/modules/openstacksti instead
test -L /etc/puppet/environments || {
    mv --backup -T /etc/puppet/environments /etc/puppet/environments.ORIG || \
        rm -rf /etc/puppet/environments
    ln -s "${OPENSTACK_STIIT_GIT_CHECKOUT_DIR}"/puppet/environments \
       /etc/puppet/environments
}

# TODO: add the openstack-sti::puppetmaster class to the current host first
puppet agent --test

echo "All done."
