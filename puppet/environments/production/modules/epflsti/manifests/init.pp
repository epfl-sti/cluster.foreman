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

    class { "epflsti::private::puppet":
      is_puppetmaster => $is_puppetmaster,
    }
    class { "ntp": }
    class { "ipmi": }
    class { "epflsti::private::unix_access":
      sudoer_group => "openstack-sti",
      allowed_users_and_groups => "(openstack-sti)"
    }
    
    if ($is_openstack_worker or $is_quorum_node) {
      class { "epflsti::private::openstack":
        is_compute_node => $is_openstack_worker,
        is_quorum_node => $is_quorum_node,
        quorum_nodes => $quorum_nodes
      }
    }
}
