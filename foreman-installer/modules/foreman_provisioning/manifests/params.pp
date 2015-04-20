class foreman_provisioning::params {
  $rails = "/usr/bin/ruby193-rails"
  $foreman_topdir = "/usr/share/foreman"
  $state_dir = "/var/lib/foreman-installer/foreman_provisioning"
  $puppet_facts_dir = "/var/lib/puppet/yaml/facts"
  $facts_push_stamp_dir = "/var/lib/puppet/yaml/foreman"
  $node_rb = "/etc/puppet/node.rb"
}
