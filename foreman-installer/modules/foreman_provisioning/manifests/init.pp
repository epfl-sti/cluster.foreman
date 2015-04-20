# = Class: foreman_provisioning
#
# Same as running Foreman's "set up provisioning" wizard, but on full
# auto. Answers are asked at install time (e.g. by
# epfl-sti/cluster.foreman.git's configure.pl), instead of
# foreman_setup's weird and error-prone workflow of having to go to a
# Web UI first, and then re-run foreman-installer a second time.
#
# === Parameters:
# 
# $interface::          The name of the network interface connected to the
#                       provisioning network
# $domain_name::        The domain name to set on provisioned hosts
# $network_address::    The IP network address of the provisioning network
# $netmask::            The netmask of the network to provision into
# $gateway::            The gateway to set on provisioned hosts
# $dns::                The IP of the DNS server to set on provisioned hosts
# $dhcp_range::         Range of addresses to allocate for provisioning
# $foreman_topdir::     The directory where to run "${rails} runner" from
# $state_dir::          The directory where to write state files
# $rails::              The full path of the rails utility
# $puppet_facts_dir::   The directory that contains Puppet-generated YAML fact
#                       files for each host (in order to add one for this host)
class foreman_provisioning(
  $interface           = undef,
  $domain_name         = undef,
  $network_address     = undef,
  $netmask             = undef,
  $gateway             = undef,
  $dns                 = undef,
  $dhcp_range          = undef,
  $foreman_topdir      = $::foreman_provisioning::params::foreman_topdir,
  $state_dir           = $::foreman_provisioning::params::state_dir,
  $rails               = $::foreman_provisioning::params::rails,
  $puppet_facts_dir    = $::foreman_provisioning::params::puppet_facts_dir,
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
    ensure => "directory"
  } ->
  exec { "create ${puppet_facts_file}" :
    command => "${state_dir}/create-facts-yaml.pl \
      > ${puppet_facts_file}",
    creates => $puppet_facts_file,
    require => Package["puppet"]
    # The script (created above) is also automagically counted as a dependency
  } ->
  exec { "upload ${puppet_facts_file}" :
    command => "/etc/puppet/node.rb --push-facts",  # See above re dependencies
    unless => "/usr/bin/test -f '${breadcrumb_files[upload_facts]}'"
  } ->
  file { "${breadcrumb_files[upload_facts]}":
    ensure => "present",
    require => File[$state_dir]
  } ->
  ## Uncomment the line below to take a db:dump just before running the wizard
  ## See the project wiki on how to restore the dump so as to debug
  ## setup-provisioning.rb
#  exec { 'XXX DEBUG': command => "/usr/sbin/foreman-rake db:dump" } ->
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
                Class["foreman::database"],
                Class["foreman::plugin::setup"],
                # Prerequisite #2 in step 1 of the Web wizard: (prereqs #1 and
                # #3 being provided by the uploading of facts, above)
                Class["::foreman_proxy::register"],
                ],
    unless => "/usr/bin/test -f '${breadcrumb_files[setup_provisioning]}'",
  } ->
  file { "${breadcrumb_files[setup_provisioning]}":
    ensure => "present",
    require => File[$state_dir]
  }
}
