# Dockerfile for Foreman-in-Docker, part one: the prerequisites
#
# See also ../foreman/Dockerfile for the useable version
# Built on top of Ubuntu, because why the hell not.
FROM ubuntu:latest
MAINTAINER STIIT Dev <stiitdev@groupes.epfl.ch>

# DEBIAN_FRONTEND=noninteractive avoids debconf trying to ask questions and erroring out:
# http://askubuntu.com/questions/506158/unable-to-initialize-frontend-dialog-when-using-ssh
ENV DEBIAN_FRONTEND=noninteractive 

RUN apt-get -q update && apt-get -qy dist-upgrade && apt-get -qy install wget ca-certificates

# Comfort items for debugging
RUN apt-get -qy install vim strace tcpdump lsof
# Get a "docker" PS1 prompt
RUN echo 'export "LANG=C.UTF-8"' >> /root/.bashrc
RUN echo "PS1='⚠DOCKER! \u@\h:\w\$ '" >> /root/.bashrc

# http://theforeman.org/manuals/1.9/index.html#3.InstallingForeman
RUN wget -q https://apt.puppetlabs.com/puppetlabs-release-trusty.deb
RUN dpkg -i puppetlabs-release-trusty.deb
RUN echo "deb http://deb.theforeman.org/ trusty 1.9" > /etc/apt/sources.list.d/foreman.list
RUN echo "deb http://deb.theforeman.org/ plugins 1.9" >> /etc/apt/sources.list.d/foreman.list
RUN wget -q http://deb.theforeman.org/pubkey.gpg -O- | apt-key add -
RUN apt-get -q update && \
    apt-get -qy install foreman foreman-installer ruby \
                       ruby-foreman-discovery ruby-foreman-column-view \
                       ruby-foreman-templates \
                       ruby-hammer-cli-foreman \
                       tftp tftpd-hpa xinetd git

# enable => true doesn't work in an Ubuntu-based container:
RUN perl -i.ORIG -pe 's/(^\s*enable\s*=>\s*(true|\$))/# $1/g'  \
   /usr/share/foreman-installer/modules/tftp/manifests/service.pp \
   /usr/share/foreman-installer/modules/dhcp/manifests/init.pp \
   /usr/share/foreman-installer/modules/puppet/manifests/agent/service.pp \
   /usr/share/foreman-installer/modules/puppet/manifests/server/service.pp

# Hack so that "foreman-rake console -- --sandbox" works.
RUN perl -i -pe 's/(\[ -f Gemfile \] &&)/$1 . q( [ $1 != 'console' ] &&)/e' /usr/sbin/foreman-rake
# Hack so that veth interfaces don't clog up the "interfaces" view
RUN perl -i -ne 'if (m/^(.*)def ignored_interfaces/) { <>; <>; print $1, qq(def ignored_interfaces\n), $1, q{  /\A(lo(?!cal_area_connection)|usb|vnet|veth|docker|br)/}, qq(\n), $1, qq(end\n) } else { print }' /usr/share/foreman/app/services/fact_parser.rb

# http://librarian-puppet.com/
RUN gem install librarian-puppet

# Moar debugging tools
RUN gem install debugger

# Run foreman-installer a first time, just to drag in as many packages as possible
# With tricks from
# https://github.com/riskable/docker-foreman/blob/master/install_foreman.sh
# TODO: speed this up somehow (e.g. find a way to not attempt to start daemons)
RUN mv /usr/share/foreman-installer/checks/hostname.rb /usr/share/foreman-installer/checks_hostname.rb.BAK
ADD foreman-installer-answers-stub.yaml /etc/foreman/foreman-installer-answers.yaml
RUN env FACTER_fqdn=$(hostname) FACTER_domain="local" foreman-installer -v \
    --enable-foreman-cli \
    --enable-foreman-proxy \
    --foreman-proxy-register-in-foreman=false \
    --enable-foreman-plugin-setup \
    --enable-foreman-plugin-discovery \
    --foreman-plugin-discovery-install-images
RUN mv /usr/share/foreman-installer/checks_hostname.rb.BAK /usr/share/foreman-installer/checks/hostname.rb

# Remove all traces of the random hostname that was in use during the build;
# and then double-check that they are all gone.
RUN service postgresql start && echo "drop database foreman" | sudo -u foreman psql template1 && service postgresql stop
RUN sudo -u postgres /usr/lib/postgresql/*/bin/pg_resetxlog /var/lib/postgresql/*/main/
RUN find /var/lib/puppet \
    /var/cache/foreman \
    /var/cache/bind/zones \
    -type f -delete
RUN find /etc -type f | xargs grep -l 'File managed with puppet' | xargs rm
RUN rm -rf /var/lib/puppet/concat/* \
    /etc/puppet/puppet.conf \
    /etc/hammer/cli.modules.d/foreman.yml \
    /etc/foreman/foreman-installer-answers.yaml             \
    /etc/apache2/apache2.conf                               \
    /etc/apache2/sites-available/25-puppet.conf             \
    /etc/apache2/sites-available/05-foreman.conf            \
    /etc/apache2/sites-available/05-foreman-ssl.conf        \
    /etc/foreman-proxy/settings.d/templates.yml             \
    /etc/foreman-proxy/settings.d/puppet.yml                \  
    /etc/puppet/foreman.yaml \
    /etc/puppet/hiera.yaml

# In case you were idly tampering with the container while it was being built:
RUN rm -f /root/.bash_history
    
RUN find / -xdev \
     -path /var/log -prune -false -o -type f \
     -not -path /etc/hostname \
     -not -path /etc/hosts \
     -print0 | \
    xargs -0 grep -l $(cat /etc/hostname) | \
    perl -ne 'if ($. == 1) { warn "Still some files containing the forbidden hostname:\n"}; print STDERR $_; END { die if $. }'

# Install networking stuff:
RUN apt-get -qy install iptables

ADD pipework/pipework /usr/local/bin/pipework
RUN chmod +x /usr/local/bin/pipework

# Install supervisord for the "run" phase:
RUN apt-get -y install supervisor
ADD supervisord.conf /etc/supervisor/

# Add dependencies for IPMI (foreman-installer only takes care of them
# in part)
RUN apt-get -qy install ruby-rubyipmi

# EPFLSTI-specific customizations
ADD foreman_column_view.yaml /etc/foreman/plugins/foreman_column_view.yaml
ADD ignored_environments.yml /usr/share/foreman/config/ignored_environments.yml
RUN mkdir -p /usr/share/foreman-installer/modules/interactive_configure/manifests
ADD interactive_configure.pp /usr/share/foreman-installer/modules/interactive_configure/manifests/init.pp
RUN rm -rf /etc/puppet/environments/*
RUN mkdir -p /etc/puppet/environments/production/modules
WORKDIR /etc/puppet/environments/production/modules
RUN ln -s /cluster.foreman/puppet/environments/production/modules/epflsti .
# Add puppet-ipmi module with our own patch to autodetect IPMI interfaces:
RUN set -e -x; git clone https://github.com/epfl-sti/puppet-ipmi.git ipmi; cd ipmi; ln -s .. modules; librarian-puppet install --verbose

WORKDIR /
RUN mkdir /cluster.foreman
# Keep this list in sync with dockerer and ../scripts/build
VOLUME /var/lib/puppet
VOLUME /var/lib/postgresql
VOLUME /var/lib/dhcp
VOLUME /var/lib/tftpboot
VOLUME /var/cache/bind
VOLUME /etc/puppet
VOLUME /etc/foreman
VOLUME /etc/foreman-proxy
VOLUME /root
