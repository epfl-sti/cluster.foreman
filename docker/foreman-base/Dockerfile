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
RUN echo "PS1='[\t]⚠DOCKER! \u@\h:\w\$ '" >> /root/.bashrc

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


# enable => true doesn't work on Ubuntu:
RUN sed -i s/"enable    => true,"/"#enable    => true,"/g  /usr/share/foreman-installer/modules/tftp/manifests/service.pp

# Run foreman-installer a first time, just to drag in as many packages as possible
# With tricks from
# https://github.com/riskable/docker-foreman/blob/master/install_foreman.sh
RUN rm /usr/share/foreman-installer/checks/hostname.rb
RUN env FACTER_fqdn=$(hostname) foreman-installer -v \
    --enable-foreman-proxy \
    --enable-foreman-plugin-setup \
    --enable-foreman-plugin-discovery \
    --foreman-plugin-discovery-install-images \
    || true

RUN DEBIAN_FRONTEND=noninteractive apt-get -qy install iptables

RUN wget https://raw.github.com/jpetazzo/pipework/master/pipework
RUN chmod +x pipework


# Remove all traces of the random hostname that was in use during the build.
RUN grep 'server *= ' /etc/puppet/puppet.conf | cut -d= -f2 | cut -c2- \
    > /etc/DOCKER-BUILD-HOSTNAME
RUN find / -xdev -type f -not -name DOCKER-BUILD-HOSTNAME -print0 | \
    xargs -0 grep -l $(cat /etc/DOCKER-BUILD-HOSTNAME) | \
    perl -ne 'if ($. == 1) { warn "Still some files containing the forbidden hostnames:\n"}; print STDERR $_; END { die if $. }'
