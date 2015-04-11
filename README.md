# EPFL STI clusters with Foreman

This depot contains a customized version of
[foreman-installer](http://theforeman.org/manuals/1.7/index.html#3.InstallingForeman)
and some [Puppet](https://puppetlabs.com/) code to deploy
("provision") and administer servers in a cluster with
[Foreman](http://theforeman.org/).

Through the Foreman Web interface, the cluster administrator is able
to first **provision** nodes (using DHCP, DNS, TFTP, PXE and/or IPMI),
then **administer** them (by assigning nodes to Puppet classes, and
setting Puppet variables). As a fringe benefit, a basic form of
**monitoring** is provided by storing and browsing the
[Puppet reports](https://docs.puppetlabs.com/guides/reporting.html) of
the nodes.

## Quick Start

You will need a machine with RedHat 6.6 or CentOS 6.6 installed<sup>[1](#footnote1)</sup>.

Launch `./install-provisioning-server.sh` to install foreman with the
correct configuration setup on the master node. (Alternatively if you
haven't checked out the sources yst, take a look at the `wget`
incantations at the top of [`install-provisioning-server.sh`](https://github.com/epfl-sti/cluster.foreman/blob/master/install-provisioning-server.sh))

For further information, see the [wiki](https://github.com/epfl-sti/cluster.foreman/wiki).

