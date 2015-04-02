# Fedora 20 is no RedHat 6.6 but it's the closest we have.
FROM fedora:20
MAINTAINER Nicolas Borboën <nicolas.borboen@epfl.ch>

RUN yum -y groupinstall "Development Tools"
RUN yum -y install which

RUN mkdir -p /opt/src
ADD bashrc /root/.bashrc
