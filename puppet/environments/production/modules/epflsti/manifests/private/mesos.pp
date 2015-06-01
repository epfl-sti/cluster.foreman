# Class: epflsti::private::mesos
#
# Install Mesos on workers and quorum nodes
#
# === Parameters
#
# $is_compute_node::      True iff VMs can run on this node
# $is_quorum_node::       True iff this host is dedicated to "rigid" services such
#                         as RabbitMQ that require a fixed set of IP addresses
# $quorum_nodes::         List of FQDNs of hosts that have $is_compute_node set
class epflsti::private::mesos(
  $is_compute_node       = false,
  $is_quorum_node        = false,
  $quorum_nodes          = []
) {
    class { "::mesos":
      repo => "mesosphere",
      manage_python => true
    }

    case $::operatingsystem {
      'RedHat', 'CentOS': {
        if ($::operatingsystemrelease =~ /^6/) {
          # Work around https://projects.puppetlabs.com/issues/11989
          $force_provider = "upstart"
        } elsif ($::operatingsystemrelease =~ /^7/) {
          $force_provider = undef
        } else {
          fail "FAIL: operating system release not supported (${::operatingsystem} release ${::operatingsystemrelease})"
        }
      }
      default: {
        fail "FAIL: operating system not supported (${::operatingsystem})"
      }
    }

    if ($is_compute_node) {
      class { "mesos::slave":
        force_provider => $force_provider
      }
    }
    if ($is_quorum_node) {
      class { "mesos::master":
        force_provider => $force_provider
      }
    }
}
