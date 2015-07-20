# EPFL-STI-style clusters with Foreman

This depot contains a Dockerized version of
[foreman-installer](http://theforeman.org/manuals/1.8/index.html#3.InstallingForeman)
and some [Puppet](https://puppetlabs.com/) code to ensure that
that Docker image can later be moved around in your cluster.

## Quick Start

1. Select a machine to run the first few containers; it needs not run
CoreOS or any particular operating system, but you should be able to
ssh into it as root.
2. Run `./configure.pl`
3. Run `./docker/dockerer build mysubdomain.mydomain.com`, where
  `mysubdomain.mydomain.com` is an as-of-yet nonexistent domain
3. Run `./docker/dockerer run mysubdomain.mydomain.com`

For further information, see the [wiki](https://github.com/epfl-sti/cluster.foreman/wiki).

