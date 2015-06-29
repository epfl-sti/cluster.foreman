# Dockerfile for Foreman-in-Docker, part one: the prerequisites
#
# See also ../foreman/Dockerfile for the useable version
# Built on top of Ubuntu, because why the hell not.
FROM ubuntu:latest
MAINTAINER STIIT Dev <stiitdev@groupes.epfl.ch>

# DEBIAN_FRONTEND=noninteractive avoids debconf trying to ask questions and erroring out:
# http://askubuntu.com/questions/506158/unable-to-initialize-frontend-dialog-when-using-ssh
RUN apt-get -q update && DEBIAN_FRONTEND=noninteractive apt-get -qy dist-upgrade && DEBIAN_FRONTEND=noninteractive apt-get -qy install wget tftp tftpd-hpa vim

# Get a "docker" PS1 prompt
RUN echo "PS1='⚠DOCKER! \u@\h:\w\$ '" >> /root/.bashrc

# http://theforeman.org/manuals/1.8/index.html#2.1Installation
RUN DEBIAN_FRONTEND=noninteractive apt-get -qy install ca-certificates
RUN wget -q https://apt.puppetlabs.com/puppetlabs-release-trusty.deb
RUN dpkg -i puppetlabs-release-trusty.deb
RUN echo "deb http://deb.theforeman.org/ trusty 1.8" > /etc/apt/sources.list.d/foreman.list
RUN echo "deb http://deb.theforeman.org/ plugins 1.8" >> /etc/apt/sources.list.d/foreman.list
RUN wget -q http://deb.theforeman.org/pubkey.gpg -O- | apt-key add -
RUN apt-get -q update && \
    DEBIAN_FRONTEND=noninteractive apt-get -qy install foreman-installer \
                       ruby-foreman-discovery ruby-foreman-column-view


# enable => true doesn't work in an Ubuntu-based container:
RUN perl -i.ORIG -pe 's/(^\s*enable\s*=>\s*(true|\$))/# $1/g'  \
   /usr/share/foreman-installer/modules/tftp/manifests/service.pp \
   /usr/share/foreman-installer/modules/dhcp/manifests/init.pp \
   /usr/share/foreman-installer/modules/puppet/manifests/agent/service.pp \
   /usr/share/foreman-installer/modules/puppet/manifests/server/service.pp

# Run foreman-installer a first time, just to drag in as many packages as possible
# With tricks from
# https://github.com/riskable/docker-foreman/blob/master/install_foreman.sh
# TODO: speed this up somehow (e.g. find a way to not attempt to start daemons)
RUN mv /usr/share/foreman-installer/checks/hostname.rb /usr/share/foreman-installer/checks_hostname.rb.BAK
ADD foreman-installer-answers-stub.yaml /etc/foreman/foreman-installer-answers.yaml
RUN env FACTER_fqdn=$(hostname) foreman-installer -v \
    --enable-foreman-proxy \
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
    
RUN find / -xdev \
     -path /var/log -prune -false -o -type f \
     -not -path /etc/hostname \
     -not -path /etc/hosts \
     -print0 | \
    xargs -0 grep -l $(cat /etc/hostname) | \
    perl -ne 'if ($. == 1) { warn "Still some files containing the forbidden hostname:\n"}; print STDERR $_; END { die if $. }'

# Install networking stuff:

RUN DEBIAN_FRONTEND=noninteractive apt-get -qy install iptables

RUN wget https://raw.github.com/jpetazzo/pipework/master/pipework
RUN chmod +x pipework

# Install supervisord for the "run" phase:
RUN apt-get -y install supervisor

# Customizations for EPFLSTI-specific code
ADD foreman_column_view.yaml /etc/foreman/plugins/foreman_column_view.yaml
RUN rm -rf /etc/puppet/environments/*
RUN ln -s /cluster.foreman/puppet/environments/production /etc/puppet/environments/production


RUN mkdir /cluster.foreman
VOLUME /cluster.foreman
