# cluster.foreman.community-templates
EPFL-STI's templates for Foreman provisioning 

## Quick Start

1. Get a Foreman installation going, for instance [using epfl-sti/cluster.foreman](https://github.com/epfl-sti/cluster.foreman)
1. Install the [foreman_templates plugin](https://github.com/theforeman/foreman_templates)
2. Type <pre>foreman-rake templates:sync prefix='"STI-IT "' \
          repo='https://github.com/epfl-sti/cluster.foreman.community-templates.git'</pre>
3. A couple of templates with names starting with “STI-IT” should show up under Hosts → Provisioning templates

See https://github.com/theforeman/community-templates for more provisioning templates.

## Contents

CoreOS mostly, as we are quite infatuated of CoreOS these days, at least [as long as you don't restart etcd too much](https://github.com/coreos/etcd/issues/863).

## TODO

* Adopt etcd2
* Implement zero-click enrollment into Puppet CA (somewhat difficult – Requires running Puppet to create the keys *before* rebooting)
* Foreman and/or Puppet should dictate some of the network parameters, instead of them being hard-coded (name of the internal interface, and whether the default route goes through the gateway VIP)
