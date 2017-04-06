# Dockerfile for Puppet-in-Docker
#
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

RUN set -e -x; wget -q http://apt.puppetlabs.com/puppetlabs-release-pc1-xenial.deb ; dpkg -i puppetlabs-release-pc1-xenial.deb; rm puppetlabs-release-pc1-xenial.deb

RUN apt -q update && \
    apt -qy install git puppet

VOLUME /etc/puppet/modules
VOLUME /var/lib/puppet/ssl
EXPOSE 8140

ENTRYPOINT ["/usr/bin/puppet"]
CMD ["master", "--no-daemonize"]
