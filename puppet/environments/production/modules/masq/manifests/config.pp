# == Class masq::config
#
# This class is called from masq
#
class masq::config {

  sysctl { 'net.ipv4.ip_forward':
    ensure    => $masq::ensure,
    permanent => 'yes',
    value     => '1',
  }

  firewall { '900 masq':
    chain => 'POSTROUTING',
    jump  => 'MASQUERADE',
    proto => 'all',
    table => 'nat',
  }
}
