# = Class: git::params
#
# Customizations to foreman-installer that are specific to EPFL STI.
#
# This file is being symlinked as
# /usr/share/foreman-installer/modules/epflsti/manifests/init.pp by
# configure.pl, and then loaded by foreman-installer
# as part of its job.
#
# === Parameters:
#
# $configure_answers::      Ignored - This is a placeholder for the
#                           configure.pl script to persist the answers
#                           provided by the user
# $src_path::               The path where epfl-sti/cluster.foreman.git is
#                           checked out
# $provisioning_interface:: The name of the network interface connected to the
#                           provisioning network
# $provisioning_domain_name:: The domain name to set on provisioned hosts
# $provisioning_network_address:: The IP network address of the provisioning
#                                  network
# $provisioning_netmask::   The netmask of the network to provision into
# $provisioning_gateway::   The gateway to set on provisioned hosts
# $provisioning_dns::       The IP of the DNS server to set on provisioned
#                            hosts
# $provisioning_dhcp_range:: Range of addresses to allocate for provisioning
# $rails::                  The full path of the rails utility
# $foreman_topdir::         The directory where to run "foreman runner" from
# $foreman_vardir::         The directory where to write breadcrumb files
class epflsti(
  $configure_answers = {},
  $src_path = undef,
  $provisioning_interface       = undef,
  $provisioning_domain_name     = undef,
  $provisioning_network_address = undef,
  $provisioning_netmask         = undef,
  $provisioning_gateway         = undef,
  $provisioning_dns             = undef,
  $provisioning_dhcp_range      = undef,
  $foreman_topdir               = $::epflsti::params::foreman_topdir,
  $foreman_vardir               = $::epflsti::params::foreman_vardir,
  $rails                        = $::epflsti::params::rails,
  ) inherits epflsti::params {
  if $src_path == undef {
    fail '$src_path must be set'
  }

  foreman::plugin {'column_view':
    config => template('epflsti/foreman_column_view_yaml.erb')
  }

  $setup_provisioning_breadcrumb_file = "${foreman_vardir}/setup-provisioning.done"

  exec { 'setup provisioning in Foreman':
    command => "${rails} runner -e production ${src_path}/foreman-installer/scripts/setup-provisioning.rb \
    --interface-name=${provisioning_interface} \
    --domain-name=${provisioning_domain_name} \
    --network-address=${provisioning_network_address} \
    --netmask=${provisioning_netmask} \
    --gateway=${provisioning_gateway} \
    --dns-primary=${provisioning_dns} \
    --dhcp-range=$provisioning_dhcp_range",
    cwd => $foreman_topdir,
    user => "foreman",
    unless => "/usr/bin/test -f '${setup_provisioning_breadcrumb_file}'",
    require => [
                Class["foreman::database"],
                Class["foreman::plugin::setup"],
                ],
  } ->
  file { "${setup_provisioning_breadcrumb_file}":
    ensure => "present"
  }
}
