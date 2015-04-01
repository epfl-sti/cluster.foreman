# Class: openstack-sti::computenode
#
# This class describes an ordinary OpenStack-STI compute node.
#
# All nodes ought to be completely interchangeable.
class openstack-sti::computenode() inherits openstack-sti {
    class { "mesos":
      repo => "mesosphere",
      manage_python => true
    }
    class { "mesos::slave":
      # Work around https://projects.puppetlabs.com/issues/11989
      force_provider => "upstart"
    }
}
