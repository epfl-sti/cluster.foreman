# https://github.com/jpetazzo/pxe/blob/master/Dockerfile
FROM ubuntu:latest
MAINTAINER Nicolas Borboën <nicolas.borboen@epfl.ch>

RUN apt-get update && apt-get -y install wget

# http://theforeman.org/manuals/1.8/index.html#2.1Installation
RUN apt-get -y install ca-certificates
RUN wget https://apt.puppetlabs.com/puppetlabs-release-trusty.deb
RUN dpkg -i puppetlabs-release-trusty.deb
RUN echo "deb http://deb.theforeman.org/ trusty 1.8" > /etc/apt/sources.list.d/foreman.list
RUN echo "deb http://deb.theforeman.org/ plugins 1.8" >> /etc/apt/sources.list.d/foreman.list
RUN wget -q http://deb.theforeman.org/pubkey.gpg -O- | apt-key add -
RUN apt-get update && apt-get -y install foreman-installer

RUN apt-get -qy install iptables

RUN wget --no-check-certificate https://raw.github.com/jpetazzo/pipework/master/pipework
RUN chmod +x pipework

# Run foreman-installer a first time, just to drag in as many packages as possible
# With tricks from
# https://github.com/riskable/docker-foreman/blob/master/install_foreman.sh
RUN rm /usr/share/foreman-installer/checks/hostname.rb
RUN env FACTER_fqdn=$(hostname) foreman-installer || true
RUN rm /etc/foreman/foreman-installer-answers.yaml


RUN apt-get install libyaml-tiny-perl
RUN mkdir /docker-build
ADD run-foreman-installer.pl /docker-build/run-foreman-installer.pl

# This needs to be done as late as possible, otherwise each reconfiguration entails
# a large amount of duplicate work
ADD foreman-installer-answers.yaml /etc/foreman/foreman-installer-answers.yaml

RUN perl /docker-build/run-foreman-installer.pl

RUN /bin/false  # XXX

RUN mkdir pxelinux.cfg
RUN printf "DEFAULT linux\nKERNEL linux\nAPPEND initrd=initrd.gz\n" >pxelinux.cfg/default
CMD \
    echo Setting up iptables... &&\
    iptables -t nat -A POSTROUTING -j MASQUERADE &&\
    echo Waiting for pipework to give us the eth1 interface... &&\
    /pipework --wait &&\
    myIP=$(ip addr show dev eth1 | awk -F '[ /]+' '/global/ {print $3}') &&\
    mySUBNET=$(echo $myIP | cut -d '.' -f 1,2,3) &&\
    echo Starting DHCP+TFTP server...&&\
    dnsmasq --interface=eth1 \
    	    --dhcp-range=$mySUBNET.101,$mySUBNET.199,255.255.255.0,1h \
	    --dhcp-boot=pxelinux.0,pxeserver,$myIP \
	    --pxe-service=x86PC,"Install Linux",pxelinux \
	    --enable-tftp --tftp-root=/tftp/ --no-daemon
# Let's be honest: I don't know if the --pxe-service option is necessary.
# The iPXE loader in QEMU boots without it.  But I know how some PXE ROMs
# can be picky, so I decided to leave it, since it shouldn't hurt.
