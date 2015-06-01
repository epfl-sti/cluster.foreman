# Puppet configuration (master and slaves)
#
# === Parameters
#
# $is_puppetmaster::      True iff this node acts as the puppet master
# $src_dir::        The directory where https://github.com/epfl-sti/cluster.foreman/
#                   has been checked out
class epflsti::private::puppet(
  $is_puppetmaster         = false,
  $src_dir = "/opt/src/cluster.foreman"
  ) {
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
  if ($is_puppetmaster) {
      package { 'foreman':
              ensure => 'present',
      }
      exec { 'latest_hammer':
        command => "${src_dir}/puppet/scripts/install_latest_hammer",
        unless => "${src_dir}/puppet/scripts/install_latest_hammer --check-only"
      } ->
      exec { 'configure_discovery_templates':
        command => "${src_dir}/puppet/scripts/configure_discovery_templates",
        unless => "${src_dir}/puppet/scripts/configure_discovery_templates --check-only",
      }
  }
}
