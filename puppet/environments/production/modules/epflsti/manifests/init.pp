# Class: epflsti
#
# Base class for epflsti::puppetmaster, epflsti::computenode
# and epflsti::quorumnode.
#
# You probably want to use one of the subclasses from Foreman or puppet.conf.
class epflsti(
  $ensure         = 'present',
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
