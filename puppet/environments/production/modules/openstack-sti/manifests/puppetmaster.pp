# Class: puppetmaster
#
# This class describes an OpenStack-STI puppetmaster.
#
# At the moment, there is exactly one of these per cluster, and it
# manages bare-metal provisioning (using Foreman) in addition to being
# the puppetmaster.

class openstack-sti::puppetmaster(
  $src_dir = "/opt/src/epfl.openstack-sti.foreman"
  ) {
      package { 'puppet':
              ensure => 'present',
      }
      package { 'foreman':
              ensure => 'present',
      }
      exec { 'latest_hammer':
        command => "${src_dir}/puppet/scripts/install_latest_hammer",
        unless => "${src_dir}/puppet/scripts/install_latest_hammer --check-only"
      }
      exec { 'configure_discovery_templates':
        command => "${src_dir}/puppet/scripts/configure_discovery_templates",
        unless => "${src_dir}/puppet/scripts/configure_discovery_templates --check-only",
        require => Exec["latest_hammer"],
      }
      class { "dnsclient":
        nameservers => [ '127.0.0.1' ],
        domain => "epfl.ch"
      }
      class { "ntp": }

      # Act as a masquerading proxy, assuming the compute nodes will use us
      # as their default route.
      # https://forge.puppetlabs.com/bashtoni/masq
      class { 'firewall': }
      class { 'masq': }
}
