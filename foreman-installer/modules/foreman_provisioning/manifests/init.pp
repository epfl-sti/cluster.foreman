# = Class: foreman_provisioning
#
# Same as running Foreman's "set up provisioning" wizard, but on full
# auto. Answers are asked at install time (e.g. by
# epfl-sti/cluster.foreman.git's configure.pl), instead of
# foreman_setup's weird and error-prone workflow of having to go to a
# Web UI first, and then re-run foreman-installer a second time.
#
# Tour guide: search for "STEP " in the comments below.
#
# === Parameters:
# 
# $interface::            The name of the network interface connected to the
#                         provisioning network
# $domain_name::          The domain name to set on provisioned hosts
# $network_address::      The IP network address of the provisioning network
# $netmask::              The netmask of the network to provision into
# $gateway::              The gateway to set on provisioned hosts
# $dns::                  The IP of the DNS server to set on provisioned hosts
# $dhcp_range::           Range of addresses to allocate for provisioning
# $foreman_topdir::       The directory where to run "${rails} runner" from
# $state_dir::            The directory where to write state files
# $rails::                The full path of the rails utility
# $puppet_facts_dir::     The directory that contains Puppet-generated YAML
#                         fact files for each host (in order to add one for
#                         this host)
# $facts_push_stamp_dir:: The directory where /etc/puppet/node.rb keeps the
#                         stamp files regarding the facts it pushes
# $node_rb::              The path to the node.rb script
class foreman_provisioning(
  $interface            = undef,
  $domain_name          = undef,
  $network_address      = undef,
  $netmask              = undef,
  $gateway              = undef,
  $dns                  = undef,
  $dhcp_range           = undef,
  $foreman_topdir       = $::foreman_provisioning::params::foreman_topdir,
  $state_dir            = $::foreman_provisioning::params::state_dir,
  $rails                = $::foreman_provisioning::params::rails,
  $puppet_facts_dir     = $::foreman_provisioning::params::puppet_facts_dir,
  $facts_push_stamp_dir = $::foreman_provisioning::params::facts_push_stamp_dir,
  $node_rb              = $::foreman_provisioning::params::node_rb
  ) inherits foreman_provisioning::params {
  validate_string($interface, $domain_name, $network_address, $netmask,
                  $gateway, $dns, $dhcp_range)

  # http://stackoverflow.com/a/29730655/435004
  exec { "Create ${state_dir}":
    creates => $state_dir,
    command => "mkdir -p ${state_dir}",
    path => [ "/bin/", "/sbin/" , "/usr/bin/", "/usr/sbin/" ]
  } -> file { $state_dir : }

  # Sigh. Puppet doesn't let you know the path of its stuff, forcing you to
  # create copies to run the bundled scripts.
  file { "${state_dir}/create-facts-yaml.pl":
    ensure => "present",
    content => file("foreman_provisioning/create-facts-yaml.pl"),
    mode => 755,
    require => File[$state_dir]
  }
  file { "${state_dir}/setup-provisioning.rb":
    ensure => "present",
    content => file("foreman_provisioning/setup-provisioning.rb"),
    require => File[$state_dir]
  }

  $breadcrumb_files = {
    upload_facts   => "${state_dir}/upload-facts.done",
    setup_provisioning => "${state_dir}/setup-provisioning.done",
  }

  $puppet_facts_file = "${puppet_facts_dir}/${::fqdn}.yaml"
  file { $puppet_facts_dir :
    ensure => "directory",
    owner => "puppet",
    group => "puppet"
  } ->
  # STEP 1: our create-facts-yaml.pl script creates a Puppet-style
  # fact file, unless it already exists.
  exec { "create ${puppet_facts_file}" :
    command => "${state_dir}/create-facts-yaml.pl > ${puppet_facts_file} && \
                chown puppet:puppet ${puppet_facts_file}",
    # create-facts-yaml.pl is also automagically counted as a dependency
    creates => $puppet_facts_file,
    require => Package["puppet"]
  } ->
  # STEP 2: we call foreman's /etc/puppet/node.rb to push the facts
  # into the Foreman database. This creates a Host object and some
  # Fact objects, including the network configuration, to meet prerequisites
  # #1 and #3 of foreman_setup's Web wizard.
  exec { "upload ${puppet_facts_file}" :
    command => "/bin/rm ${facts_push_stamp_dir}/${::fqdn}-push-facts.yaml ; ${node_rb} --push-facts",
    unless => "/usr/bin/test -f '${breadcrumb_files[upload_facts]}'",
    require => Service["puppet"]
  } ->
  file { "${breadcrumb_files[upload_facts]}":
    ensure => "present",
    require => File[$state_dir]
  } ->
  ## Uncomment the line below to take a db:dump just before running the wizard
  ## See the project wiki on how to restore the dump so as to debug
  ## setup-provisioning.rb
#  exec { 'XXX DEBUG': command => "/usr/sbin/foreman-rake db:dump" } ->

  ## STEP 3: our setup-provisioning.rb script runs the same Ruby on
  ## Rails controller as the Web wizard, but on full auto.
  exec { 'setup provisioning in Foreman':
    command => "${rails} runner -e production \
    ${state_dir}/setup-provisioning.rb \
    --interface-name=${interface} \
    --domain-name=${domain_name} \
    --network-address=${network_address} \
    --netmask=${netmask} \
    --gateway=${gateway} \
    --dns-primary=${dns} \
    --dhcp-range=$dhcp_range",
    cwd => $foreman_topdir,
    user => "foreman",
    require => [
                File["${state_dir}/setup-provisioning.rb"],
                # Service["postgres"],
                # Class["foreman::plugin::setup"],
                # This ensures prerequisite #2 in step 1 of the Web wizard:
                Class["::foreman_proxy::register"],
                ],
    unless => "/usr/bin/test -f '${breadcrumb_files[setup_provisioning]}'",
  } ->
  file { "${breadcrumb_files[setup_provisioning]}":
    ensure => "present",
    require => File[$state_dir]
  }
}
