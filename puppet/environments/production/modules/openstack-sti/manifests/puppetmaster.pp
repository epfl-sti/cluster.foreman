# Class: puppetmaster
#
# This class describes an OpenStack-STI puppetmaster.
#
# At the moment, there is exactly one of these per cluster, and it
# manages bare-metal provisioning (using Foreman) in addition to being
# the puppetmaster.

class openstack-sti::puppetmaster {
      package { 'puppet':
              ensure => 'present',
      }
      exec { 'latest_hammer':
        command => "/opt/src/epfl.openstack-sti.foreman/scripts/ensure_latest_hammer",
      }
      exec { 'configure_discovery_templates':
        command => "/opt/src/epfl.openstack-sti.foreman/scripts/configure_discovery_templates",
        require => Exec["latest_hammer"],
      }
        
}
