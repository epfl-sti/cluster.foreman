# Class: epflsti
#
# Single entry point for all EPFLSTI cluster nodes.
#
# Class parameters specify the functionality.
#
# === Parameters
#
# [*is_openstack_compute_node*]
#   A Boolean
#
class epflsti(
  $is_openstack_compute_node = false,
) {
    case $::osfamily {
      'RedHat': {
        if $::operatingsystemmajrelease = '6' {
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
        } elsif $::operatingsystemmajrelease = '7' {
          package { 'puppetlabs-release-7':
            ensure => 'latest',
            provider => 'rpm',
            source => 'https://yum.puppetlabs.com/puppetlabs-release-el-7.noarch.rpm'
          }
          package { 'puppet':
            ensure => 'latest',
            require => Package['puppetlabs-release-7']
          }
          package { 'facter':
            ensure => 'latest',
            require => Package['puppetlabs-release-7']
          }
        } else {
          warning( 'Invalid operatingsystemmajrelease in /etc/puppet/environments/production/modules/epflsti/manifests/init.pp' )
        }
      }
      default: {
          fail('Unsupported OS in /etc/puppet/environments/production/modules/epflsti/manifests/init.pp')
      }
    }
    class { "ntp": }
    class { "ipmi": }

    if ($is_openstack_compute_node) {
      class { "epflsti::private::openstack": }
    }
  }
