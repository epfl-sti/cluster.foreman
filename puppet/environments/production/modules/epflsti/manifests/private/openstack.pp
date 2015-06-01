# Class: epflsti::private::openstack
#
# Install OpenStack from https://rdoproject.org/'s PackStack
#
# === Parameters
#
# $is_compute_node::      True iff VMs can run on this node
# $is_quorum_node::       True iff this host is dedicated to "rigid" services such
#                         as RabbitMQ that require a fixed set of IP addresses
# $quorum_nodes::         List of FQDNs of hosts that have $is_compute_node set
class epflsti::private::openstack(
  $is_compute_node       = false,
  $is_quorum_node        = false,
  $quorum_nodes          = []
  ) {
  case $::operatingsystem {
    'RedHat', 'CentOS': {
      if ($::operatingsystemrelease =~ /^6/) {
        $distro_specific_repo_subdir = "epel-6"
      } elsif ($::operatingsystemrelease =~ /^7/) {
        $distro_specific_repo_subdir = "epel-7"
      } else {
        fail "FAIL: operating system release not supported (${::operatingsystem} release ${::operatingsystemrelease})"
      }
    }
    default: {
      fail "FAIL: operating system not supported (${::operatingsystem})"
    }
  }

  yumrepo { 'openstack-havana':
    ensure => present,
    descr => "OpenStack Icehouse Repository",
    baseurl => "https://repos.fedorapeople.org/repos/openstack/openstack-icehouse/${distro_specific_repo_subdir}/",
    gpgcheck => 1,
    gpgkey => "https://raw.githubusercontent.com/puppetlabs/puppetlabs-openstack/master/files/RPM-GPG-KEY-RDO-Icehouse",
  }

  package { 'openstack-packstack':
    ensure => latest
  }

  file { '/etc/packstack':
    ensure => directory
  } -> file { '/etc/packstack/packstack-answers.txt':
    ensure => file,
    content => template("epflsti/packstack-answers.txt.erb")
  }
}
