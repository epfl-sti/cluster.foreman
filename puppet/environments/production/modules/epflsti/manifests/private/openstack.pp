# Class: epflsti::private::openstack
#
# Install OpenStack from https://rdoproject.org/'s PackStack
#
class epflsti::private::openstack() {
  # https://serverfault.com/questions/111766/adding-a-yum-repo-to-puppet-before-doing-anything-else
  Yumrepo <| |> -> Package <| provider != 'rpm' |>

  yumrepo { 'openstack-havana':
    ensure => present,
    descr => "OpenStack Havana Repository",
    baseurl => "http://repos.fedorapeople.org/repos/openstack/EOL/openstack-havana/epel-6/",
    gpgcheck => 1,
    gpgkey => "https://raw.githubusercontent.com/stackforge/puppet-openstack/master/files/RPM-GPG-KEY-RDO-Havana",
  }

  package { 'openstack-packstack':
    ensure => installed
  }
}
