# Class: epflsti::private::openstack
#
# Install OpenStack from https://rdoproject.org/'s PackStack
#
class epflsti::private::openstack() {
  # https://serverfault.com/questions/111766/adding-a-yum-repo-to-puppet-before-doing-anything-else
  Yumrepo <| |> -> Package <| provider != 'rpm' |>

  yumrepo { 'openstack-havana':
    ensure => present,
    descr => "OpenStack Icehouse Repository",
    baseurl => "https://repos.fedorapeople.org/repos/openstack/openstack-icehouse/epel-6/",
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
