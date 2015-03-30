# Class: openstack-sti::quorumnode
#
# This class describes "special" services of openstack-sti that require fixed
# instances.  The number of nodes that install this in a cluster should be
# kept low and constant (say 3 or 5). In low count clusters, nodes may use
# belong to both the openstack-sti::quorumnode and openstack-sti::computenode
# classes.
class openstack-sti::quorumnode() inherits openstack-sti {
    class { "mesos":
      repo => "mesosphere",
      manage_python => true
    }
    class { "mesos::master":
      # Work around https://projects.puppetlabs.com/issues/11989
      force_provider => "upstart"
    }
}

