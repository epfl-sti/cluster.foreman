FROM centos:6.6
MAINTAINER Nicolas Borboën <nicolas.borboen@epfl.ch>

RUN yum -y groupinstall "Development Tools"
RUN yum -y install which tar gzip bzip2

RUN mkdir -p /opt/src
ADD bashrc /root/.bashrc
