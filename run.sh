#!/bin/sh

# Usage:
#   wget -O /tmp/run.sh https://raw.githubusercontent.com/domq/epfl.openstack-sti.foreman/master/run.sh
#   OPENSTACK_STIIT_INTERNAL_IFACE=eth1 bash /tmp/run.sh
#
# One unfortunately *cannot* just pipe wget into bash, because
# foreman-installer wants a tty :(
#
# Please keep this script:
#  * repeatable: it should be okay to run it twice
#  * readable (with comments in english)
#  * minimalistic: complicated things should be done with Puppet instead

set -e -x

rpm -q epel-release-6-8 || \
  rpm -ivh http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
rpm -qa | grep puppetlabs-release || \
  rpm -ivh http://yum.puppetlabs.com/puppetlabs-release-el-6.noarch.rpm

which foreman-installer || {
    # TODO: this is currently untested.
    yum-config-manager --enable rhel-6-server-optional-rpms rhel-server-rhscl-6-rpms
    yum -y install http://yum.theforeman.org/releases/1.7/el6/x86_64/foreman-release.rpm
}
 
# The : ${foo:=bar} mantra keeps foo from the environment, with bar as
# the default value.
: ${OPENSTACK_STIIT_INTERNAL_IFACE:=eth1}
: ${OPENSTACK_STIIT_MASTER_HOSTNAME:="$(hostname --short)"}
# TODO: ask user with sane defaults from parsing ifconfig or something.
: ${OPENSTACK_STIIT_IPADDRESS=192.168.10.1}
: ${OPENSTACK_STIIT_DHCP_RANGE="192.168.10.32 192.168.10.127"}
: ${OPENSTACK_STIIT_CLUSTER_DOMAIN=epfl.ch}
: ${OPENSTACK_STIIT_MASTER_FQDN="${OPENSTACK_STIIT_MASTER_HOSTNAME}.${OPENSTACK_STIIT_CLUSTER_DOMAIN}"}

test -z "${OPENSTACK_STIIT_SKIP_FOREMAN_INSTALLER}" && foreman-installer \
  --enable-foreman-plugin-discovery \
  --foreman-plugin-discovery-install-images=true \
  --enable-foreman-proxy \
  --foreman-proxy-tftp=true \
  --foreman-proxy-tftp-servername="$OPENSTACK_STIIT_IPADDRESS" \
  --foreman-proxy-dhcp=true \
  --foreman-proxy-dhcp-interface=eth1 \
  --foreman-proxy-dhcp-gateway="$OPENSTACK_STIIT_IPADDRESS" \
  --foreman-proxy-dhcp-range="$OPENSTACK_STIIT_DHCP_RANGE" \
  --foreman-proxy-dhcp-nameservers="$OPENSTACK_STIIT_IPADDRESS" \
  --foreman-proxy-dns=true \
  --foreman-proxy-dns-interface="$OPENSTACK_STIIT_INTERNAL_IFACE" \
  --foreman-proxy-dns-zone="$OPENSTACK_STIIT_CLUSTER_DOMAIN" \
  --foreman-proxy-dns-reverse=10.168.192.in-addr.arpa \
  --foreman-proxy-dns-forwarders=128.178.15.228 \
  --foreman-proxy-dns-forwarders=128.178.15.227 \
  --foreman-proxy-foreman-base-url=https://"$OPENSTACK_STIIT_MASTER_FQDN"

# TODO: this should clearly be done from Puppet.
tftpboot_fdi_dir=/var/lib/tftpboot/boot
fdi_image="$tftpboot_fdi_dir"/fdi-image-latest.tar
test -f "$fdi_image" || wget -O "$fdi_image" \
  http://downloads.theforeman.org/discovery/releases/latest/fdi-image-latest.tar

test -d "$tftpboot_fdi_dir"/fdi-image || \
  tar --overwrite -C"$tftpboot_fdi_dir" -xf "$fdi_image"

# Hopefully hammer works out-of-the-box as a CLI bridge to the
# API. (See
# /usr/share/foreman-installer/modules/foreman/manifests/cli.pp)
#
# It does, because the admin password somehow goes into
# /root/.hammer/cli.modules.d/foreman.yml – Presumably because of
# Puppet magic built in foreman-installer.
#
# TODO: use it (preferably through Puppet) to configure the basics of
# Foreman: LDAP server, openstack-sti@ as admin group, and all the
# tweaks needed to get CentOS to install when selected (binding
# between provisioning templates, OS, host groups and environments)

echo "All done."
