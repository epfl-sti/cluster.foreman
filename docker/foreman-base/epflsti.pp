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
  exec { "copy Puppet keys for puppetdb":
    command => "puppetdb-ssl-setup",
    path => $::path,
    creates => $::puppetdb::params::ssl_key_path,
    require => File[$::puppet::server::ssl_cert_key]
  } -> Service[$::puppetdb::params::puppet_service_name]
}
