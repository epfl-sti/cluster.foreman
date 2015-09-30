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
3. Run <pre>./docker/dockerer build mysubdomain.mydomain.com</pre> where
  `mysubdomain.mydomain.com` is an as-of-yet nonexistent domain
3. Run <pre>./docker/dockerer run mysubdomain.mydomain.com</pre>

For further information, see the [wiki](https://github.com/epfl-sti/cluster.foreman/wiki).

## Hacking

You can enter the running Docker by typing `docker exec -it puppetmaster.mysubdomain.mydomain.com /bin/bash`

## CoreOS Install Templates

A couple of Foreman templates are provided under `coreos/` to help install CoreOS and Puppet on your nodes (using [epfl-sti/cluster.coreos.puppet](https://github.com/epfl-sti/cluster.coreos.puppet)).

1. <pre>docker exec -it puppetmaster.mysubdomain.mydomain.com /bin/bash</pre>
2. Install the [foreman_templates plugin](https://github.com/theforeman/foreman_templates) (TODO: should be provided as part of the Docker image)
3. <pre>foreman-rake templates:sync prefix='"STI-IT "' \
          repo='https://github.com/epfl-sti/cluster.foreman.community-templates.git'</pre>
