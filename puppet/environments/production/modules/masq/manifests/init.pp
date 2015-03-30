# == Class: masq
#
# Sets up iptables masquerading
#
class masq {

  unless ($::kernel == 'Linux') {
    fail("Sorry, ${::kernel} is unsupported")
  }

  class { 'masq::config': } ~>
  Class['masq']
}
