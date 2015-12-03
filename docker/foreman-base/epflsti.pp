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
  File[$::puppet::server::ssl_cert_key] ->
  exec { "copy Puppet keys for puppetdb":
    command => "puppetdb-ssl-setup",
    path => $::path,
    creates => $::puppetdb::params::ssl_key_path,
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
    exec { "puppetdb_conn_validator curl ${name}":
      path => $::path,
      command => "timeout ${timeout} bash -c 'set -x; while ! curl -k -v --cert /var/lib/puppet/ssl/certs/${::fqdn}.pem --key /var/lib/puppet/ssl/private_keys/${::fqdn}.pem ${_proto}://${puppetdb_server}:${puppetdb_port}${test_url}; do sleep 10; done'"
    }
}
