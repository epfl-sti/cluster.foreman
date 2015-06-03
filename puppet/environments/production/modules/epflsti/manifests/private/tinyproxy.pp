# Class: epflsti::private::tinyproxy
#
# Make internal Web servers accessible to savvy users who know that they can
# ssh -L 8888:127.0.0.1:8888 <frontend>
# Note: the tinyproxy class is not posted on Puppet Forge (yet).
# One has to
# cd /etc/puppet/environments/production/modules
# git clone git@github.com:jlyheden/puppet-tinyproxy.git tinyproxy
class epflsti::private::tinyproxy(
  $puppet_modules_dir = "/etc/puppet/environments/production/modules",
  $puppet_tinyproxy_github_address = "https://github.com/jlyheden/puppet-tinyproxy.git",
  $port = 8888) {
    $git_checkout_dir = "${puppet_modules_dir}/tinyproxy"
    exec { "git clone ${puppet_tinyproxy_github_address} tinyproxy":
      cwd => $puppet_modules_dir,
      path => $::path,
      unless => "test -d ${git_checkout_dir}"
    }
    if ('true' == inline_template('<%= File.directory?(@git_checkout_dir) %>')) {
      class { '::tinyproxy':
        listen             => '127.0.0.1',
        port               => 8888,
      }
    }
}
