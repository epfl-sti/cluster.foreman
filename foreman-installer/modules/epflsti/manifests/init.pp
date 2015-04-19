# = Class: epflsti
#
# Customizations to foreman-installer that are specific to EPFL STI.
#
# This file is being symlinked as
# /usr/share/foreman-installer/modules/epflsti/manifests/init.pp by
# configure.pl, and then loaded by foreman-installer
# as part of its job.
#
# === Parameters:
#
# $configure_answers::      Ignored - This is a placeholder for the
#                           configure.pl script to persist the answers
#                           provided by the user
# $src_path::               The path where epfl-sti/cluster.foreman.git is
#                           checked out
class epflsti(
  $configure_answers = {},
  $src_path = undef,
  ) inherits epflsti::params {
  validate_absolute_path($src_path)

  foreman::plugin {'column_view':
    config => template('epflsti/foreman_column_view_yaml.erb')
  }
}
