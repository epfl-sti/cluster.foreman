# Class: computenode
#
# This class describes an ordinary OpenStack-STI compute node.
#
# All nodes ought to be completely interchangeable.
class openstack-sti::computenode(
  $src_dir = "/opt/src/epfl.openstack-sti.foreman"
  ) {
  class { "ntp": }
  class { "ipmi": }
}
