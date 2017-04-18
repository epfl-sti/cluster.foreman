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
3. <pre>foreman-rake templates:sync prefix="STI-IT " \
          repo=https://github.com/epfl-sti/cluster.foreman.git filter=CoreOS</pre>

## TO-DO

* Multi-docker
  + Images:
    - Foreman UI
    - PostgreSQL (stock)
    - Puppet master + Puppet PKI (on volume) + Puppetdb + Foreman ENC + smart proxy (configurable)
    - TFTP server + discovery infrastructure + smart proxy (configurable)
    - Whatever it takes to run Ansible
  + Testability / objectives:
    - It Works™
    - Ability to "docker rm" the TFTP server and restore its state from scratch at
    - Ability to "docker rm" the Puppet container and restore from only the config and PKI state
    - From "docker rm" both the Foreman UI and the PostgreSQL database to ready-to-use, with minimal number of click-only, business-only steps
      - Auto-insert into Puppet PKI
      - Discover / type in the smart proxies
      - Bootstrap admin access somehow (custom UI to obtain PKCS#12 from Puppet CA?)
    - dump / restore sidekick for PostgreSQL
      - UI / API: press button, receive DB dump
      - automated: to configurable storage (local disk, Ceph)
  + Credential + config bootstrap
    - PostgreSQL's init is stand-alone
      - SSL with self-signed cert
      - chooses root password
    - Puppet CA auto-generates if not existing yet
    - Initiating arrows between Foreman and the smart proxies is the most involved part
      - Everyone can pick up the CA cert easily, and send in their CSRs
      - Probably want to tell Puppet CA autosign for a number of well-known cert names - So far so good
      - And then, somehow authority to operate the Foreman UI must flow to the administrator...
      - And finally, administrator locks down the whole thing by disabling the autosign entries.
      - In any case, configs must come first (before PKI is locked down)
    
    - Foreman config must come before Foreman cred bootstrap
      - Needs to know own endpoint hostname for HTTP/S certificate (see below)
      - Needs to obtain IP addresses of other Dockers
      - Might as well receive an entire business-specific config dump at bootstrap time
    - Foreman UI obtains the arrows it needs... somehow (will probably require out-of-band admin operation)
      - Puppet CA cert (easy)
      - 
      - Puppet CA's smart proxy credential (hard — Must obtain signed cert out-of-band)
      - PostgreSQL (ad-hoc)
      - Smart proxies (easy, as soon as Foreman has HTTP/S client cert in hand)
    - More magic required to propagate the Puppet CA to Foreman
      - Foreman issues cert req, sends to Puppet CA
      - Foreman uses already existing creds so sign own cert (is this something that already works?)
      - Foreman configures itself with received cert and restarts
      - Foreman still needs a way to authenticate the first admin
