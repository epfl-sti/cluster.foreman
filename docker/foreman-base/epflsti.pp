# = Class: epflsti
#
# EPFLSTI-specific enhancements to foreman-installer
#
# === Parameters:
#
# $interactive_answers::   Ignored - This is just a placeholder for
#                 the configure.pl script to persist the user-provided
#                 answers
class epflsti(
  $interactive_answers = {}
) {

  # Copy certificate, private key and CA from Puppet to puppetdb
  exec { "copy Puppet keys for puppetdb":
    command => "puppetdb ssl-setup",
    path => $::path,
    creates => $::puppetdb::params::ssl_key_path,
    require =>   [File[$::puppet::server::ssl_cert_key],
                  Class["::puppet::server::config"]]
  } ->
  Service[$::puppetdb::params::puppet_service_name]
}

# Override puppetdb's puppetdb_conn_validator with our own version
# that doesn't insist on using the agent code paths (which we can't,
# since the Puppetmaster-in-Docker doesn't run the agent)
define puppetdb_conn_validator (
  $puppetdb_server = $::fqdn,
  $puppetdb_port   = 8081,
  $use_ssl         = true,
  $timeout         = 120,
  $test_url        = "/v3/version") {
    $_proto = $use_ssl ? {
      false    => "http",
      default => "https"
    }

    Exec["copy Puppet keys for puppetdb"] ->
    Service["puppetdb"] ->
    exec { "puppetdb_conn_validator curl ${name}":
      path => $::path,
      command => "timeout ${timeout} bash -c 'set -x; while ! curl -k -v --cert ${::foreman::params::puppet_ssldir}/certs/${::fqdn}.pem --key ${::foreman::params::puppet_ssldir}/private_keys/${::fqdn}.pem ${_proto}://${puppetdb_server}:${puppetdb_port}${test_url}; do sleep 10; done'"
    }
}
