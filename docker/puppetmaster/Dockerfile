# Dockerfile for Puppet-in-Docker
#
FROM ubuntu:latest
MAINTAINER STIIT Dev <stiitdev@groupes.epfl.ch>

# DEBIAN_FRONTEND=noninteractive avoids debconf trying to ask questions and erroring out:
# http://askubuntu.com/questions/506158/unable-to-initialize-frontend-dialog-when-using-ssh
ENV DEBIAN_FRONTEND=noninteractive 

# Still necessary for puppetdb, even if we use Ubuntu's Puppet
RUN apt -q update && apt -qy dist-upgrade && apt-get -qy remove --purge systemd && apt -qy install wget ca-certificates git supervisor
RUN set -e -x; wget -q http://apt.puppetlabs.com/puppetlabs-release-pc1-xenial.deb ; dpkg -i puppetlabs-release-pc1-xenial.deb; rm puppetlabs-release-pc1-xenial.deb
RUN apt -q update && apt -qy install puppet puppetdb 

# There's no systemd here, but rather supervisord.
RUN puppet module install dskad/supervisor_provider
RUN find /usr/lib/ruby/vendor_ruby/puppet/provider/service/ -type f \( -not -name base.rb -not -name service.rb \) -delete

# Install PuppetDB as per https://docs.puppet.com/puppetdb/4.4/install_via_module.html and plumb down all moving parts with supervisor
RUN puppet module install puppetlabs/puppetdb
RUN puppet apply -e 'class { "puppetdb": database => "embedded" }'

# Comfort items for debugging
RUN apt -qy install vim strace tcpdump lsof silversearcher-ag

VOLUME /etc/puppet/modules
VOLUME /var/lib/puppet/ssl
EXPOSE 8140

ENTRYPOINT ["/usr/bin/puppet"]
CMD ["master", "--no-daemonize"]
