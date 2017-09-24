# Dockerfile for Foreman-in-Docker
#
# Built on top of Ubuntu, because why the hell not.
FROM ubuntu:17.10
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

RUN set -e -x; wget -q https://apt.puppetlabs.com/puppet5-release-xenial.deb ; dpkg -i puppet5-release-xenial.deb; rm puppet5-release-xenial.deb

# https://theforeman.org/manuals/1.15/quickstart_guide.html
RUN echo "deb http://deb.theforeman.org/ xenial 1.15" > /etc/apt/sources.list.d/foreman.list
RUN echo "deb http://deb.theforeman.org/ plugins 1.15" >> /etc/apt/sources.list.d/foreman.list
RUN wget -q http://deb.theforeman.org/pubkey.gpg -O- | apt-key add -
RUN apt -q update && \
    apt -qy install locales supervisor dirmngr \
                tftp tftpd-hpa xinetd git postgresql iptables-persistent \
                docker.io \
                perl libipc-system-simple-perl libnetaddr-ip-perl libyaml-tiny-perl \
                foreman foreman-installer \
                ruby \
                ruby-rubyipmi \
                ruby-foreman-discovery \
                ruby-foreman-column-view \
                ruby-foreman-templates \
                ruby-hammer-cli-foreman \
                ruby-foreman-cockpit \
                ruby-foreman-dhcp-browser \
                puppetserver puppet-agent puppetdb puppetdb-termini \
                ruby-puppetdb-foreman \
                puppet-agent-puppet-strings puppet-agent-oauth
RUN rm -f /core || true

# http://librarian-puppet.com/
RUN gem install librarian-puppet

# Requirement of "puppet query events"
RUN gem install chronic

# Moar debugging tools
RUN gem install byebug

# Ensure we get a reasonable locale setup (wanted by PostgreSQL DB creation)
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8

# https://github.com/theforeman/foreman/pull/3398
RUN wget -q -O/usr/share/foreman/lib/tasks/console.rake https://raw.githubusercontent.com/epfl-sti/foreman/develop/lib/tasks/console.rake

# Hack: services cannot actually run in a Docker container (except PostgreSQL, which must)
RUN find /opt/puppetlabs/puppet/lib/ruby/vendor_ruby/puppet/provider/service -type f -not -name service.rb -not -name init.rb -not -name base.rb -delete
ADD service-mocks.rb /opt/puppetlabs/puppet/lib/ruby/vendor_ruby/puppet/provider/service/service-mocks.rb

# Requirement of puppet-agent-puppet-strings, itself needed to read
# the flags out of custom foreman-installer modules (such as our epflsti one)
RUN /opt/puppetlabs/puppet/bin/gem install rgen

# Run foreman-installer a first time, just to drag in as many packages as possible
# With tricks from
# https://github.com/riskable/docker-foreman/blob/master/install_foreman.sh
# https://groups.google.com/forum/#!topic/foreman-users/8qb2fhtbNEI
ADD foreman-installer-custom-hiera.yaml /etc/foreman-installer/custom-hiera.yaml
RUN mv /usr/share/foreman-installer/checks/hostname.rb /usr/share/foreman-installer/checks_hostname.rb.BAK
ADD foreman-installer-answers-stub.yaml /etc/foreman-installer/scenarios.d/foreman-answers.yaml
RUN mkdir -p /var/lib/tftpboot/boot  # O_RLY? YA_RLY
RUN rm /usr/share/foreman-installer/modules/foreman/lib/facter/sssd.rb  # Spurious warning
ENV STDLIB_LOG_DEPRECATIONS=false
RUN bash -c 'if ! env FACTER_fqdn="$(hostname).local" FACTER_domain="local" foreman-installer -v \
    --enable-foreman-cli \
    --enable-foreman-proxy \
    --foreman-proxy-register-in-foreman=false \
    --enable-foreman-plugin-setup \
    --enable-foreman-plugin-discovery \
    --foreman-plugin-discovery-install-images ;  \
    then cat /var/log/foreman-installer/foreman.log; exit 1 ; fi'
RUN mv /usr/share/foreman-installer/checks_hostname.rb.BAK /usr/share/foreman-installer/checks/hostname.rb

# Purge all default environments; keep only production
RUN rm -rf /etc/puppetlabs/code/environments/*
RUN mkdir -p /etc/puppetlabs/code/environments/production/modules

# Make "puppet query" work against the puppetdb
ENV PATH=/opt/puppetlabs/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
RUN puppet module install dalen-puppetdbquery

# Remove all traces of the random hostname that was in use during the build;
# and then double-check that they are all gone.
RUN set -e -x; service postgresql start; for i in $(seq 1 3); do echo "drop database foreman" | sudo -u foreman psql template1 && break; sleep 20; done;  service postgresql stop
RUN sudo -u postgres /usr/lib/postgresql/*/bin/pg_resetxlog /var/lib/postgresql/*/main/
RUN find \
    /opt/puppetlabs/puppet/cache/puppet-module/cache \
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

# Provide a set of useful debugging commands
ADD bash_history /root/.bash_history

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
RUN git clone https://github.com/epfl-sti/cluster.coreos.puppet.git epflsti_coreos; cd epflsti_coreos; ln -s .. modules; librarian-puppet install
# Add puppet-ipmi module patch to autodetect IPMI interfaces:
RUN set -e -x; git clone https://github.com/jhoblitt/puppet-ipmi.git ipmi; cd ipmi; ln -s .. modules; librarian-puppet install
# Replace the puppetdb_conn_validator type with our own define() (see epflsti.pp)
RUN rm -rf /usr/share/foreman-installer/modules/puppetdb/lib/puppet/provider/puppetdb_conn_validator \
  /usr/share/foreman-installer/modules/puppetdb/lib/puppet/type/puppetdb_conn_validator.rb
# Add our own /ipmi/index mini-app
WORKDIR /usr/share/foreman
RUN perl -i -pe 'm/Foreman::Application\.routes\.draw/ || next; \
  print; $seen = 1; $_ = qq{  get "ipmi/index"\n\n}; END { die unless $seen }' config/routes.rb

ADD foreman-ipmi/ /usr/share/foreman

# Initialization scripts
ADD supervisord.conf /etc/supervisor/
ADD entrypoint /entrypoint
RUN chmod 755 /entrypoint
RUN mkdir /scripts
ADD configure.pl /scripts
ADD setup-networking /scripts
RUN chmod 755 /scripts/*
ADD lib /usr/local/lib/site_perl

# Finalize the image.
# Volumes must be declared last (after we are done mutating them).
WORKDIR /
VOLUME [ "/var/lib/puppet", "/var/lib/postgresql", "/var/lib/dhcp", \
         "/var/lib/tftpboot", "/var/cache/bind", "/etc/puppet", "/etc/foreman", \
         "/etc/foreman-installer", "/etc/foreman-proxy", "/root" ]

CMD /entrypoint
