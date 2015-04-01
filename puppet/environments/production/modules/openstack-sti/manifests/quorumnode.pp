# Class: openstack-sti::quorumnode
#
# This class describes "special" services of openstack-sti that require fixed
# instances.  The number of nodes that install this in a cluster should be
# kept low and constant (say 3 or 5). In low count clusters, nodes may use
# belong to both the openstack-sti::quorumnode and openstack-sti::computenode
# classes.
class openstack-sti::quorumnode(
  $quorum_node_id = undef,      # Must be an int between 1 and $count
  $quorum_node_id_max = undef,  # Must be an int
  ) inherits openstack-sti {
    if !(is_integer($quorum_node_id)) {
      fail('$quorum_node_id must be an integer')
    }
    if !(is_integer($quorum_node_id_max)) {
      fail('$quorum_node_id_max must be an integer')
    }
    if !($quorum_node_id >= 1) {
      fail("$quorum_node_id must be positive (got ${quorum_node_id})")
    }
    if !($quorum_node_id <= $quorum_node_id_max) {
      fail("$quorum_node_id (${$quorum_node_id_}) must be no larger than $quorum_id_max (got ${quorum_node_id_max})")
    }
    notice("This is node ${quorum_node_id} of ${quorum_node_id_max}")
#    class { 'zookeeper':
#      packages             => ['zookeeper', 'zookeeper-server'],
#      service_name         => 'zookeeper-server',
#      initialize_datastore => true
#    }
    class { "mesos":
      repo => "mesosphere",
      manage_python => true
    }
    class { "mesos::master":
      # Work around https://projects.puppetlabs.com/issues/11989
      force_provider => "upstart"
    }
}

