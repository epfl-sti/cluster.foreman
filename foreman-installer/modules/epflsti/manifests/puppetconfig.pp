# = Class: epflsti::puppetconfig
#
# Take control of the configuration for the "real" Puppet instance.
#
# In function puppet__server_environments of configure.pl, we tell the
# stock foreman-installer not to worry about /etc/puppet/environments,
# as we make our own symlink to the checked out sources here.
#
# === Parameters:
#
# $production_env_dir::       What directory to use as
#                             /etc/puppet/environments/production
class epflsti::puppetconfig (
  $production_env_dir = undef
) {
  validate_absolute_path($production_env_dir)

  file { "/etc/puppet/environments/production":
    ensure => "symlink",
    target => $production_env_dir,
    # puppet agent would create /etc/puppet/environments/production as
    # a directory if it doesn't exist by then:
    before => Class["Puppet::Agent::Service"],
  }

  # This is left over by the puppet-server RPM
  file { "/etc/puppet/environments/example_env":
    ensure => "absent",
    force => true
  }
}
