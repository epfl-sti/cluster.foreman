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

# Supervisor logs go to "docker logs", thanks to
# https://pypi.python.org/pypi/supervisor-stdout


file { ["/etc/supervisor", "/etc/supervisor/conf.d", "/var/log/supervisor" ]:
  ensure => "directory"
}

file { "/etc/supervisor/supervisord.conf":
  content => "
; supervisor config file

[unix_http_server]
file=/var/run/supervisor.sock   ; (the path to the socket file)
chmod=0700                       ; sockef file mode (default 0700)

[supervisord]
logfile=/dev/stdout
pidfile=/var/run/supervisord.pid ; (supervisord pidfile;default supervisord.pid)
childlogdir=/var/log/supervisor            ; ('AUTO' child log dir, default $TEMP)

; the below section must remain in the config file for RPC
; (supervisorctl/web interface) to work, additional interfaces may be
; added by defining them in separate rpcinterface: sections
[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

[supervisorctl]
serverurl=unix:///var/run/supervisor.sock ; use a unix:// URL  for a unix socket

; The [include] section can just contain the 'files' setting.  This
; setting can list multiple files (separated by whitespace or
; newlines).  It can also contain wildcards.  The filenames are
; interpreted as relative to this file.  Included files *cannot*
; include files themselves.

[include]
files = /etc/supervisor/conf.d/*.conf
"
}

file { "/etc/supervisor/conf.d/eventlistener.conf":
  content => "
[eventlistener:stdout]
command = supervisor_stdout
buffer_size = 100
events = PROCESS_LOG
result_handler = supervisor_stdout:event_handler
"
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
