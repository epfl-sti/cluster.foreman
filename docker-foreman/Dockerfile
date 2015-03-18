# Fedora 20 is no RedHat 6.6 but it's the closest we have.
FROM fedora:20
MAINTAINER Nicolas Borboën <nicolas.borboen@epfl.ch>

RUN yum -y groupinstall "Development Tools"
RUN yum -y install which

RUN mkdir -p /opt/src
# RUN git clone https://github.com/epfl-sti/epfl.openstack-sti.foreman.git /opt/src/epfl.openstack-sti.foreman
ADD sticonfig.cfg /opt/src/epfl.openstack-sti.foreman/
ADD bashrc /root/.bashrc
