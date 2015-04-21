# = Class: epflsti
#
# Customizations to foreman-installer that are specific to EPFL STI.
#
# The epflsti directory gets symlinked as
# /usr/share/foreman-installer/modules/epflsti by configure.pl, and
# then foreman-installer loads the manifests/init.pp therein as part
# of its job.
#
# === Parameters:
#
# $configure_answers::      Ignored - This is a placeholder for the
#                           configure.pl script to persist the user-provided
#                           answers that don't have a specific YAML
#                           configuration entry of their own  
# $src_path::               The path where epfl-sti/cluster.foreman is
#                           checked out (required)
class epflsti(
  $configure_answers = {},
  $src_path = undef,
  ) inherits epflsti::params {
  validate_absolute_path($src_path)

  foreman::plugin {'column_view':
    # Loaded from ../templates:
    config => template('epflsti/foreman_column_view_yaml.erb')
  }

  # Import that class ("declare" it in Puppet lingo), with those
  # parameters, from puppetconfig.pp in the same directory:
  class { "epflsti::puppetconfig":
    production_env_dir => "${src_path}/puppet/environments/production"
  }
}
