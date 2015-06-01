# Class: epflsti::private::unix_access
#
# Manage user accounts, ssh access, and sudoers
#
# === Parameters:
#
# $allowed_users_and_groups::  access.conf(5)-style ACL, e.g.
#   "user1 user2 (group1) (group2)" - Set to the empty string to lock down ssh
#   access
#
# $sudoer_group::  The group to grant sudoer access to (without a password)
#
class epflsti::private::unix_access(
  $allowed_users_and_groups = "",
  $sudoer_group = ""
) {
  class { 'clusterssh':
    manage_nsswitch_netgroup => false,  # Left for epfl_sso to set
  }

  class { "epfl_sso":
    allowed_users_and_groups => $allowed_users_and_groups,
  }

  # Required if you want to be able to lock your .Xauthority (!):
  if ($allowed_users_and_groups != "") {
    class { 'selinux':
      mode => 'permissive'
    }
  }

  if ($sudoer_group != "") {
    class { 'sudo':
      # Don't nuke /etc/sudoers.d/foreman-proxy
      manage_sudoersd => false,
      # And don't overrule "requiretty" in /etc/sudoers.d/os_defaults on
      # the Puppet master, as that causes
      # https://groups.google.com/forum/#!topic/foreman-users/9-EtYN2D2Xs
      keep_os_defaults => false,
      defaults_hash    => merge($sudo::params::os_defaults, {
        requiretty     => false
      })
    }
    
    sudo::conf { $sudoer_group:
      content => "%${sudoer_group} ALL=(ALL) NOPASSWD: ALL",
    }
  }
}
