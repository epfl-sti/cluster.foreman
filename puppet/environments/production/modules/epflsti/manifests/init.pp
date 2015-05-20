# Class: epflsti
#
# Base class for epflsti::puppetmaster, epflsti::computenode
# and epflsti::quorumnode.
#
# You probably want to use one of the subclasses from Foreman or puppet.conf.
class epflsti(
  $ensure         = 'present',
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
}
