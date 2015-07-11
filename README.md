# EPFL-STI-style clusters with Foreman

This depot contains a Dockerized version of
[foreman-installer](http://theforeman.org/manuals/1.8/index.html#3.InstallingForeman)
and some [Puppet](https://puppetlabs.com/) code to ensure that
that Docker image can later be moved around in your cluster.

## Quick Start

You will need a machine with RedHat 7.x or CentOS 7.x installed<sup>[1](#footnote1)</sup>.

Launch `./install-provisioning-server.sh` to install foreman-in-Docker
on the head node. (Alternatively if you haven't checked out the
sources yet, take a look at the `wget` incantations at the top of
[`install-provisioning-server.sh`](https://github.com/epfl-sti/cluster.foreman/blob/master/install-provisioning-server.sh))

For further information, see the [wiki](https://github.com/epfl-sti/cluster.foreman/wiki).

