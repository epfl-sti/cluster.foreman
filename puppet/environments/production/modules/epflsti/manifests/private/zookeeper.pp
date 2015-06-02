# Class: epflsti::private::zookeeper
#
# Install ZooKeeper for an EPFLSTI cluster
#
# === Parameters
#
# $nodes::         List of FQDNs of hosts to install ZooKeeper onto
#
class epflsti::private::zookeeper(
  $nodes = []
) {
  $id = 1 + inline_template('<%= @nodes.index(@fqdn) %>')
  if (false) {
    class { "::zookeeper":
      id => $id
    }
  }
}
