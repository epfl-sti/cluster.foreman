# Class: epflsti
#
# Single entry point for all EPFLSTI cluster nodes.
#
# Class parameters specify the functionality.
#
# === Parameters
#
# $is_puppetmaster::      True iff this node acts as the puppet master
# $is_openstack_worker::  True iff OpenStack VMs can run on this node
# $is_mesos_worker::      True iff Mesos workloads can run on this node
# $is_quorum_node::       True iff this host is dedicated to "rigid" services such
#                         as ZooKeeper that require a fixed set of IP addresses
#                         (as opposed to "floating" jobs running under some kind
#                         of orchestration system on the $is_compute_node nodes)
# $quorum_nodes::         List of FQDNs of hosts that have $is_compute_node set
# $dns_domain::           The DNS domain that all nodes in the cluster live in
class epflsti(
  $is_puppetmaster         = false,
  $is_openstack_worker     = false,
  $is_mesos_worker         = false,
  $is_quorum_node          = false,
  $quorum_nodes            = $::epflsti::private::params::quorum_nodes,
  $dns_domain              = $::epflsti::private::params::dns_domain
) inherits epflsti::private::params {
    # Basic services
    class { "ntp": }
    class { "ipmi": }
    if ($is_puppetmaster) {
      # I guess I could be convinced that the puppetmaster doesn't have to
      # be the network gateway. But that's the way things are right now.
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

    # User shell access: for admins only
    class { "epflsti::private::unix_access":
      sudoer_group => "openstack-sti",
      allowed_users_and_groups => "(openstack-sti)"
    }

    # Puppet masters and slaves
    class { "epflsti::private::puppet":
      is_puppetmaster => $is_puppetmaster,
    }

    # High-level services
    if ($is_openstack_worker or $is_quorum_node) {
      class { "epflsti::private::openstack":
        is_compute_node => $is_openstack_worker,
        is_quorum_node => $is_quorum_node,
        quorum_nodes => $quorum_nodes
      }
    }
}
