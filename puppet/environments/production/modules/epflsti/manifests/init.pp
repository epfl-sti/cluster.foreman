# Class: epflsti
#
# Configuration for EPFL-STI cluster members
#
# === Parameters:
#
# $is_puppetmaster::      True iff this node acts as the puppet master
# $is_compute_node::      True iff computations (VMs and/or Dockers) can run on this
#                         node
# $quorum_nodes::         List of FQDNs of hosts that served "rigid" services such
#                         as ZooKeeper that required a fixed set of IP addresses
#                         (as opposed to "floating" jobs)
# $dns_domain::           The DNS domain that all nodes in the cluster live in
class epflsti(
  $is_puppetmaster         = false,
  $is_compute_node         = false,
  $quorum_nodes            = [],
  $dns_domain              = "cloud.epfl.ch"
) {
  package { 'puppetlabs-release-6':
    ensure => 'latest',
    provider => 'rpm',
    source => 'https://yum.puppetlabs.com/puppetlabs-release-el-6.noarch.rpm'
  }
  package { 'puppet':
    ensure => 'latest',
    require => Package['puppetlabs-release-6']
  }
  package { 'facter':
    ensure => 'latest',
    require => Package['puppetlabs-release-6']
  }
  class { "ntp": }
  class { "ipmi": }
}
