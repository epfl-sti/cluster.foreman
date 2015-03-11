# Class: puppetmaster
#
# This class describes an OpenStack-STI puppetmaster.
#
# At the moment, there is exactly one of these per cluster, and it
# manages bare-metal provisioning (using Foreman) in addition to being
# the puppetmaster.

class openstack-sti::puppetmaster {
      package { 'puppet':
              ensure => 'present',
      }
}
