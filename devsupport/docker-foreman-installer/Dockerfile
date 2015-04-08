FROM centos:6.6
MAINTAINER Nicolas Borboën <nicolas.borboen@epfl.ch>

RUN yum -y groupinstall "Development Tools"
RUN yum -y install which tar gzip bzip2

RUN mkdir -p /opt/src
ADD bashrc /root/.bashrc

EXPOSE 443
EXPOSE 8443
# EXPOSE 69/udp  # That wouldn't actually work, instead see ../run.sh
