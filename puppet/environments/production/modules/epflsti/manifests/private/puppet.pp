# Puppet configuration for slaves
#
# The puppetmaster is in a Docker file, and is not configured with Puppet.
class epflsti::private::puppet() {
  case $::osfamily {
      'RedHat': {
        case $::operatingsystemmajrelease {
          '6': {
	    package { 'puppetlabs-release-6':
              ensure => 'latest',
              provider => 'rpm',
              source => 'https://yum.puppetlabs.com/puppetlabs-release-el-6.noarch.rpm',
              alias => "puppetlabs-release"
            }
          }
          '7': {
            package { 'puppetlabs-release-7':
              ensure => 'latest',
              provider => 'rpm',
              source => 'https://yum.puppetlabs.com/puppetlabs-release-el-7.noarch.rpm',
              alias => "puppetlabs-release"
            }
          }
          default: {
            fail("${::osfamily}-${::operatingsystemmajrelease} is not supported")
          }
        }
      }
      default: {
          fail('Unsupported OS in /etc/puppet/environments/production/modules/epflsti/manifests/init.pp')
      }
  }
  package { ['puppet', 'facter']:
    ensure => 'latest',
    require => Package['puppetlabs-release']
  }
}
