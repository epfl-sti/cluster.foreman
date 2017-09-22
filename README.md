# Foreman and Puppet in a Docker box

This depot contains a Dockerized version
of
[Foreman](http://theforeman.org/manuals/1.15/index.html#3.InstallingForeman) and
[Puppet](https://puppet.com/) version 5, and all the bells and
whistles to go with both (see below) — This image does **not** strive
for minimal size.

## What's In The Box

+ Foreman 1.15
+ Complete discovery and provisioning stack:
    + TFTP + DHCP + DNS servers
    + [Foreman discovery plugin](https://theforeman.org/plugins/foreman_discovery/index.html) and its diskless boot image
+ [Puppet](https://puppet.com/) version 5, with PuppetDB and Hiera, [librarian-puppet](http://librarian-puppet.com/)

## Quick Start

You need to understand how to run a Docker container on your platform
("bare" server with Docker, or Kubernetes), and what Docker volumes
are and how to use them.

For instance, assuming that you have your Puppet code living in
`/etc/puppet` on the host, and you want to take advantage of the
network configuration automation, run something like this:

```
docker run --rm --hostname puppetmaster.my.subdomain.example.com \
  -e /etc/puppet:/etc/puppetlabs/code/environments/production/modules \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -it epflsti/foreman-base
```


💡 It is up to you to ensure continuity of the data between upgrades of this Docker image, for instance by using the `--volumes-from` flag.

## Hacking

You can enter the running Docker by typing `docker exec -it puppetmaster.mysubdomain.mydomain.com /bin/bash`

You can run this Docker image *without* the automation and with all
scripts mounted from the host filesystem like this:

```
docker run --rm --hostname puppetmaster.my.subdomain.example.com \
   -e /etc/puppet:/etc/puppetlabs/code/environments/production/modules \
   -v /var/run/docker.sock:/var/run/docker.sock \
   -v $PWD/docker/foreman-base/lib:/usr/local/lib/site_perl \
   -v $PWD/docker/foreman-base:/scripts \
   -it epflsti/foreman-base bash
```
