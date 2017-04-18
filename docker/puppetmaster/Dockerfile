# Dockerfile for Puppet-in-Docker
#
FROM ubuntu:latest
MAINTAINER STIIT Dev <stiitdev@groupes.epfl.ch>

# DEBIAN_FRONTEND=noninteractive avoids debconf trying to ask questions and erroring out:
# http://askubuntu.com/questions/506158/unable-to-initialize-frontend-dialog-when-using-ssh
ENV DEBIAN_FRONTEND=noninteractive 

# Still necessary for puppetdb, even if we use Ubuntu's Puppet
RUN apt -q update && apt -qy dist-upgrade && apt-get -qy remove --purge systemd && apt -qy install wget ca-certificates git python-pip
RUN set -e -x; wget -q http://apt.puppetlabs.com/puppetlabs-release-pc1-xenial.deb ; dpkg -i puppetlabs-release-pc1-xenial.deb; rm puppetlabs-release-pc1-xenial.deb
RUN apt -q update && apt -qy install puppet puppetdb 
RUN pip2 install supervisor supervisor-stdout

# Finish the installation and preliminary setup using Puppet itself
RUN mkdir /etc/puppet/install
RUN puppet module install puppetlabs/dummy_service
RUN puppet module install puppetlabs/inifile
RUN puppet module install puppetlabs/puppetdb
RUN puppet module install theforeman/foreman_proxy
COPY docker_install.pp /etc/puppet/install
RUN puppet apply /etc/puppet/install/docker_install.pp

# Run the moving parts with supervisord
COPY supervisord-puppet.conf /etc/supervisor/conf.d/puppet.conf
COPY supervisord-puppetdb.conf /etc/supervisor/conf.d/puppetdb.conf
COPY supervisord-foremanproxy.conf /etc/supervisor/conf.d/foremanproxy.conf

# Comfort items for debugging
RUN apt -qy install vim strace tcpdump lsof silversearcher-ag

VOLUME /etc/puppet/modules
VOLUME /var/lib/puppet/ssl
EXPOSE 8140

# The rest of the customization is achieved with environment variables
COPY entrypoint /entrypoint
RUN chmod 0755 /entrypoint
CMD ["/entrypoint"]
