# Class: epflsti
#
# Single entry point for all EPFLSTI cluster nodes.
#
# Class parameters specify the functionality.
#
# === Parameters
#
# $is_frontend_node::     True iff this node is directly connected to the outside
#                         network and shall act as a router / ssh entry point.
# $network_gateway_ip::   VIP of the network gateway (must not be assigned to
#                         any node, not even the gateway itself)
# $network_gateway_interface::  Network interface leading "outside" on the gateway
# $is_openstack_worker::  True iff OpenStack VMs can run on this node
# $is_mesos_worker::      True iff Mesos workloads can run on this node
# $is_quorum_node::       True iff this host is dedicated to "rigid" services such
#                         as ZooKeeper that require a fixed set of IP addresses
#                         (as opposed to "floating" jobs running on the worker nodes
#                         under an orchestration system of some kind)
# $quorum_nodes::         List of FQDNs of hosts that have $is_compute_node set
# $dns_domain::           The DNS domain that all nodes in the cluster live in
# $dns_server_ip::        The IP of the DNS server, i.e. typically the VIP of
#                         the Foreman docker container
class epflsti(
  $is_frontend_node          = false,
  $network_gateway_ip        = undef,
  $network_gateway_interface = undef,
  $is_openstack_worker       = false,
  $is_mesos_worker           = false,
  $is_quorum_node            = false,
  $quorum_nodes              = $::epflsti::private::params::quorum_nodes,
  $dns_domain                = $::epflsti::private::params::dns_domain,
  $dns_server_ip             = $::epflsti::private::params::dns_server_ip
) inherits epflsti::private::params {
    validate_string($network_gateway)
    if ($is_frontend_node) {
      validate_string($network_gatewayinterface)
    }
    include "epflsti::private::bugware"

    # Networking configuration
    class { "epflsti::private::networking":
      network_role => $is_frontend_node ? {
        true: "gateway",
        default: "internal"},
      network_gateway_ip => $network_gateway_ip,
    }

    # Basic services
    class { "ntp": }
    class { "epflsti::private::ipmi": }
    class { 'locales':
      default_locale  => 'fr_CH.UTF-8',
      locales         => ['en_US.UTF-8 UTF-8', 'fr_CH.UTF-8 UTF-8'],
    }
    if ($is_frontend_node) {
      class { "dnsclient":
        nameservers => [ '127.0.0.1' ],
        domain => $dns_domain
      }
      class { "epflsti::private::gateway":
        network_gateway_interface => $network_gateway_interface
      }
    }

    # Puppet masters and slaves
    class { "epflsti::private::puppet":
      is_puppetmaster => $is_puppetmaster,
    }

    # Bare-metal shell access: for admins only
    class { "epflsti::private::unix_access":
      sudoer_group => "openstack-sti",
      allowed_users_and_groups => "(openstack-sti)"
    }
    # Decent shell experience
    package { ['vim-X11', 'vim-common', 'vim-enhanced', 'vim-minimal', 'mlocate',
               'strace', 'tcpdump', 'lsof', 'unzip', 'telnet', 'rsync','screen']:
      ensure => 'present'
    }
    # Let admins access Web services inside the cluster with
    # ssh -L 8888:127.0.0.1:8888 <frontend>
    if ($is_frontend_node) {
      class { 'epflsti::private::tinyproxy':
        port => 8888
      }
    }
  
    # Infrastructure services
    $java_package = "java-1.8.0-openjdk-headless"
    package { $java_package:
      ensure => 'present'
    }
    if ($is_quorum_node) {
      class { "epflsti::private::zookeeper":
        nodes            => $quorum_nodes,
        require          => Package[$java_package]
      }
    }
    # We use Docker also for quorum payloads (i.e. on fixed IPs and
    # ports), so just install it everywhere
    class { 'docker': }
    class { 'epflsti::private::elk': }

    # User-facing services
    if ($is_openstack_worker or $is_quorum_node) {
      class { "epflsti::private::openstack":
        is_compute_node => $is_openstack_worker,
        is_quorum_node => $is_quorum_node,
        quorum_nodes => $quorum_nodes
      }
    }
    if ($is_mesos_worker or $is_quorum_node) {
      class { "epflsti::private::mesos":
        is_compute_node => $is_mesos_worker,
        is_quorum_node => $is_quorum_node,
        quorum_nodes => $quorum_nodes
      }
    }
}
