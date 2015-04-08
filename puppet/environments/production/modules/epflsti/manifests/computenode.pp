# Class: epflsti::computenode
#
# This class describes an ordinary EPFL-STI compute node.
#
# All nodes ought to be completely interchangeable.
class epflsti::computenode() inherits epflsti {
    class { "mesos":
      repo => "mesosphere",
      manage_python => true
    }
    class { "mesos::slave":
      # Work around https://projects.puppetlabs.com/issues/11989
      force_provider => "upstart"
    }
}
