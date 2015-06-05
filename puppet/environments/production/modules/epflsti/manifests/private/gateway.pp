# Class: epflsti::private::gateway
#
# Act as a masquerading proxy, assuming the compute nodes will use us
# as their default route.
#
# === Parameters
#
# $network_gateway_interface::  Network interface leading "outside" on the gateway
#
class epflsti::private::gateway(
  $network_gateway_interface = undef
  ) {
  validate_string($network_gateway_interface)
  
  sysctl { 'net.ipv4.ip_forward':
    permanent => 'yes',
    value     => '1',
  }

  class { 'firewall': }
  firewall { '900 Puppet-configured masquerade rule':
    chain => 'POSTROUTING',
    outiface => $network_gateway_interface,
    jump  => 'MASQUERADE',
    proto => 'all',
    table => 'nat',
  }
}
