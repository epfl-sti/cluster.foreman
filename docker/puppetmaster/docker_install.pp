# This manifest runs at "docker build" time and installs and
# configures whatever it is able to.

# https://theforeman.org/manuals/1.11/index.html#3.5.5FactsandtheENC
remote_file { "/etc/puppet/node.rb":
  url => "https://raw.githubusercontent.com/theforeman/puppet-foreman/2.2.3/files/external_node_v2.rb",
  mode => "0755"
}
puppet_master_setting { "node_terminus": value => "exec" }
puppet_master_setting { "external_nodes": value => "/etc/puppet/node.rb" }


# Foreman proxy
class { "::foreman_proxy":
  register_in_foreman => false,  # Not yet, see entrypoint script
  puppet              => true,
  puppetca            => true,
  tftp                => false,
  dhcp                => false,
  dns                 => false,
  bmc                 => false,
  realm               => false
}

# https://docs.puppet.com/puppetdb/4.4/install_via_module.html
class { "puppetdb":
  database => "embedded"
}

##################### No user-serviceable parts below ###################

# As per https://forge.puppet.com/puppetlabs/dummy_service
include dummy_service

define remote_file(
  $file = $title,
  $url  = undef,
  $mode = '0644'
) {
  exec{ "/usr/bin/wget -q ${url} -O ${file}":
    creates => $file
  } ->
  file{ $file:
    mode    => $mode
  }
}

define puppet_master_setting(
  $key = $title,
  $value
) {
  ini_setting { "${title} in puppet.conf":
    ensure  => present,
    path    => '/etc/puppet/puppet.conf',
    section => 'master',
    setting => $key,
    value   => $value,
  }
}
