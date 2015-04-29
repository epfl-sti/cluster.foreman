# == Class: ipmi::params
#
# This class should be considered private.
#
# === Authors
#
# Joshua Hoblitt <jhoblitt@cpan.org>
#
# === Copyright
#
# Copyright (C) 2013 Joshua Hoblitt
#
class ipmi::params {
  case $::osfamily {
    'redhat': {
      case $::operatingsystemmajrelease {
        5: {
          # el5.x
          $ipmi_package = ['OpenIPMI', 'OpenIPMI-tools']
        }
        6, 7: {
          # el6.x
          $ipmi_package = ['OpenIPMI', 'ipmitool']
        }
        default: {
          case $::operatingsystemrelease {
            6.6: {
              # CentOS with ancient facter
              $ipmi_package = ['OpenIPMI', 'ipmitool']
            }
            default: {
              fail("Module ${module_name} is not supported on operatingsystemmajrelease ${::operatingsystemmajrelease}")
            }
          }
        }
      }
    }
    'debian': {
      case $::operatingsystemrelease {
        12.02, 14.04: {
          # debian
          $ipmi_package = ['openipmi', 'ipmitool']
        }
        default: {
          fail("Module ${module_name} is not supported on operatingsystemmajrelease ${::operatingsystemmajrelease}")
        }
      }
    }
    default: {
      fail("Module ${module_name} is not supported on ${::operatingsystem}")
    }
  }

}