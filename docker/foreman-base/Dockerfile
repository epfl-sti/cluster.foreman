# Dockerfile for Foreman-in-Docker, part one: the prerequisites
#
# See also ../foreman/Dockerfile for the useable version
# Built on top of Ubuntu, because why the hell not.
FROM ubuntu:16.04
MAINTAINER STIIT Dev <stiitdev@groupes.epfl.ch>

# DEBIAN_FRONTEND=noninteractive avoids debconf trying to ask questions and erroring out:
# http://askubuntu.com/questions/506158/unable-to-initialize-frontend-dialog-when-using-ssh
ENV DEBIAN_FRONTEND=noninteractive 

RUN apt -q update && apt -qy dist-upgrade && apt -qy install wget ca-certificates

# Comfort items for debugging
RUN apt -qy install vim strace tcpdump lsof silversearcher-ag
# Get a "docker" PS1 prompt
RUN echo 'export "LANG=C.UTF-8"' >> /root/.bashrc
RUN echo "PS1='⚠DOCKER! \u@\h:\w\$ '" >> /root/.bashrc

# https://theforeman.org/manuals/1.12/quickstart_guide.html
RUN set -e -x; wget -q http://apt.puppetlabs.com/puppetlabs-release-pc1-xenial.deb ; dpkg -i puppetlabs-release-pc1-xenial.deb; rm puppetlabs-release-pc1-xenial.deb
RUN echo "deb http://deb.theforeman.org/ xenial 1.12" > /etc/apt/sources.list.d/foreman.list
RUN echo "deb http://deb.theforeman.org/ plugins 1.12" >> /etc/apt/sources.list.d/foreman.list
RUN wget -q http://deb.theforeman.org/pubkey.gpg -O- | apt-key add -
RUN apt -q update && \
    apt -qy install supervisor iptables tftp tftpd-hpa xinetd git \
                foreman foreman-installer ruby \
                ruby-rubyipmi \
                ruby-foreman-discovery \
                ruby-foreman-column-view \
                ruby-foreman-templates \
                ruby-hammer-cli-foreman \
                ruby-foreman-cockpit \
                ruby-foreman-dhcp-browser \
                puppetdb puppetdb-terminus ruby-puppetdb-foreman

# http://librarian-puppet.com/
RUN gem install librarian-puppet

# Requirement of "puppet query events"
RUN gem install chronic

# Moar debugging tools
RUN gem install byebug

# Ensure we get a reasonable locale setup (wanted by PostgreSQL DB creation)
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8

# Install networking stuff:
RUN wget -O /usr/local/bin/pipework https://raw.githubusercontent.com/jpetazzo/pipework/master/pipework
RUN chmod +x /usr/local/bin/pipework

# Configure supervisord for the "run" phase:
ADD supervisord.conf /etc/supervisor/

# https://github.com/theforeman/foreman/pull/3398
RUN wget -q -O/usr/share/foreman/lib/tasks/console.rake https://raw.githubusercontent.com/epfl-sti/foreman/develop/lib/tasks/console.rake

# Hack: services cannot actually run in a Docker container
RUN find /opt/puppetlabs/puppet/lib/ruby/vendor_ruby/puppet/provider/service -type f -not -name service.rb -not -name init.rb -not -name base.rb -delete
ADD service-mocks.rb /opt/puppetlabs/puppet/lib/ruby/vendor_ruby/puppet/provider/service/service-mocks.rb

# Run foreman-installer a first time, just to drag in as many packages as possible
# With tricks from
# https://github.com/riskable/docker-foreman/blob/master/install_foreman.sh
RUN mv /usr/share/foreman-installer/checks/hostname.rb /usr/share/foreman-installer/checks_hostname.rb.BAK
ADD foreman-installer-answers-stub.yaml /etc/foreman-installer/scenarios.d/foreman-answers.yaml
RUN env FACTER_fqdn="$(hostname).local" FACTER_domain="local" foreman-installer -v \
    --enable-foreman-cli \
    --enable-foreman-proxy \
    --foreman-proxy-register-in-foreman=false \
    --enable-foreman-plugin-setup \
    --enable-foreman-plugin-discovery \
    --foreman-plugin-discovery-install-images
RUN mv /usr/share/foreman-installer/checks_hostname.rb.BAK /usr/share/foreman-installer/checks/hostname.rb

# Purge all default environments; keep only production
RUN rm -rf /etc/puppetlabs/code/environments/*
RUN mkdir -p /etc/puppetlabs/code/environments/production/modules

# Make "puppet query" work against the puppetdb
ENV PATH=/opt/puppetlabs/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
RUN puppet module install --version 1.6.1 dalen-puppetdbquery

# Fashion spotify/puppetexplorer as a foreman-installer plugin
RUN cd /usr/share/foreman-installer/modules; git clone https://github.com/spotify/puppet-puppetexplorer.git puppetexplorer

# Remove all traces of the random hostname that was in use during the build;
# and then double-check that they are all gone.
RUN set -e -x; service postgresql start; for i in $(seq 1 3); do echo "drop database foreman" | sudo -u foreman psql template1 && break; sleep 20; done;  service postgresql stop
RUN sudo -u postgres /usr/lib/postgresql/*/bin/pg_resetxlog /var/lib/postgresql/*/main/
RUN find \
    /opt/puppetlabs/puppet/cache \
    /var/cache/foreman \
    /var/cache/bind/zones \
    -type f -delete
RUN find /etc -type f | xargs grep -l 'File managed with puppet' | xargs rm
RUN rm -rf /var/lib/puppet/concat/* \
    /etc/puppet/puppet.conf \
    /etc/hammer/cli.modules.d/foreman.yml \
    /etc/foreman-installer/scenarios.d/foreman-answers.yaml    \
    /etc/foreman-proxy/settings.d/puppet_proxy_puppet_api.yml  \
    /etc/foreman-proxy/settings.d/puppet_proxy_legacy.yml      \
    /etc/puppetlabs/puppet/ssl/ca/inventory.txt                \
    /etc/puppetlabs/puppet/foreman.yaml                        \
    /etc/puppetlabs/puppetserver/conf.d/webserver.conf         \
    /etc/apache2/apache2.conf                                  \
    /etc/apache2/sites-available/25-puppet.conf                \
    /etc/apache2/sites-available/05-foreman.conf               \
    /etc/apache2/sites-available/05-foreman-ssl.conf           \
    /etc/foreman-proxy/settings.d/templates.yml                \
    /etc/foreman-proxy/settings.d/puppet.yml                   \  
    /etc/foreman-proxy/settings.d/dns_nsupdate_gss.yml         \
    /etc/puppet/foreman.yaml \
    /etc/puppet/hiera.yaml
    
RUN find / -xdev \
     -path /var/log -prune -false -o -type f \
     -not -path /etc/hostname \
     -not -path /etc/hosts \
     -not -path "*/.git/*" \
     -print0 | \
    xargs -0 grep -l $(cat /etc/hostname) | \
    perl -ne 'if ($. == 1) { warn "Still some files containing the forbidden hostname:\n"}; print STDERR $_; END { die if $. }'

# In case you were idly tampering with the container while it was being built:
RUN rm -f /root/.bash_history

# EPFLSTI-specific code and customizations
# We keep these at the bottom so that if you don't want these, you
# still benefit from intermediate layers built up to here.
ADD foreman_column_view.yaml /etc/foreman/plugins/foreman_column_view.yaml
ADD ignored_environments.yml /usr/share/foreman/config/ignored_environments.yml
RUN mkdir -p /usr/share/foreman-installer/modules/epflsti/manifests
ADD epflsti.pp /usr/share/foreman-installer/modules/epflsti/manifests/init.pp
WORKDIR /etc/puppetlabs/code/environments/production/modules
# Hack: put all "git clone"s *after* epflsti.pp above; this makes it easier
# to invalidate the Docker image and re-clone.
RUN git clone https://github.com/epfl-sti/cluster.coreos.puppet.git epflsti_coreos; cd epflsti_coreos; ln -s .. modules; librarian-puppet install --verbose
# Add puppet-ipmi module patch to autodetect IPMI interfaces:
RUN set -e -x; git clone https://github.com/jhoblitt/puppet-ipmi.git ipmi; cd ipmi; ln -s .. modules; librarian-puppet install --verbose
# Replace the puppetdb_conn_validator type with our own define() (see epflsti.pp)
RUN rm -rf /usr/share/foreman-installer/modules/puppetdb/lib/puppet/provider/puppetdb_conn_validator \
  /usr/share/foreman-installer/modules/puppetdb/lib/puppet/type/puppetdb_conn_validator.rb
# Add our own /ipmi/index mini-app
WORKDIR /usr/share/foreman
RUN perl -i -pe 'm/Foreman::Application\.routes\.draw/ || next; \
  print; $seen = 1; $_ = qq{  get "ipmi/index"\n\n}; END { die unless $seen }' config/routes.rb
  
ADD foreman-ipmi/ /usr/share/foreman

# Finalize the image.
# Volumes must be declared last (after we are done mutating them).
WORKDIR /
VOLUME [ "/var/lib/puppet", "/var/lib/postgresql", "/var/lib/dhcp", \
         "/var/lib/tftpboot", "/var/cache/bind", "/etc/puppet", "/etc/foreman", \
         "/etc/foreman-installer", "/etc/foreman-proxy", "/root" ]

