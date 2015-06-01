# Class: epflsti
#
# Single entry point for all EPFLSTI cluster nodes.
#
# Class parameters specify the functionality.
#
# === Parameters
#
# $is_puppetmaster::      True iff this node acts as the puppet master
# $is_compute_node::      True iff computations (VMs and/or Dockers) can run on this
#                         node
# $quorum_nodes::         List of FQDNs of hosts that served "rigid" services such
#                         as ZooKeeper that required a fixed set of IP addresses
#                         (as opposed to "floating" jobs running under some kind
#                         of orchestration system)
# $dns_domain::           The DNS domain that all nodes in the cluster live in
class epflsti(
  $is_puppetmaster         = false,
  $is_compute_node         = false,
  $quorum_nodes            = [],
  $dns_domain              = "cloud.epfl.ch"
) {

    class { "epflsti::private::puppet":
      is_puppetmaster => $is_puppetmaster,
    }
    class { "ntp": }
    class { "ipmi": }

    if ($is_openstack_compute_node) {
      class { "epflsti::private::openstack": }
    }
}
