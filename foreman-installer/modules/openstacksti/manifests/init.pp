# This file is being symlinked as
# /usr/share/foreman-installer/modules/openstacksti/manifests/init.pp by
# install-openstack-master.sh, and then loaded by foreman-installer
# as part of its job.
#
# In order to trigger this, /etc/foreman/foreman-installer-answers.yaml
# needs to contain an "openstacksti" top-level section.

class openstacksti() {
  # For now, just a test to demonstrate that the Puppet code gets executed:
  file { "/etc/a-winner-is-you":
    ensure => "directory"
  }
}
