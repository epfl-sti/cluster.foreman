# Class: epflsti::puppetmaster
#
# This class describes an Epflsti puppetmaster.
#
# At the moment, there is exactly one of these per cluster, and it
# manages bare-metal provisioning (using Foreman) in addition to being
# the puppetmaster. If it goes down, software update and provisioning
# become impossible until it is brought back up, but the cluster should
# otherwise work. We hope.
class epflsti::puppetmaster(
  $src_dir = "/opt/src/cluster.foreman"
  ) inherits epflsti {
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
        domain => "cloud.epfl.ch"
      }

      # Act as a masquerading proxy, assuming the compute nodes will use us
      # as their default route.
      # https://forge.puppetlabs.com/bashtoni/masq
      # TODO: the fault tolerance story is somewhat lacking here.
      class { 'firewall': }
      class { 'masq': }
}
