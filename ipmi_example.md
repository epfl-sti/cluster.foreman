# Configuration IPMI 

## Puppet master
```
sudo puppet module install -i /etc/puppet/environments/production/modules jhoblitt-ipmi
```
Then import new classes on https://foremanonpuppetmaster/puppetclasses

Next ```puppet agent --test``` on nodes will install/update the ipmi package.

## Example of manual IMPI configuration

Example of IMPI configuration for the node 'compute-0-01.epfl.ch'
* The node IP is: 192.168.10.101
* The IPMI IP is: 192.168.10.201

### Installation
```
yum install OpenIPMI OpenIPMI-tools
chkconfig ipmi on
service ipmi start
```

### Configuration
```
ipmitool lan set 1 ipsrc static
ipmitool lan set 1 ipaddr 192.168.10.201
ipmitool lan set 1 netmask 255.255.255.0
ipmitool lan set 1 defgw ipaddr 192.168.10.1
ipmitool lan set 1 defgw macaddr 00:25:64:3c:8c:eb
ipmitool lan set 1 arp respond on
ipmitool user set password 2 $$PASSWORD$$
ipmitool user set name 3 root
ipmitool user set password 3 $$PASSWORD$$
ipmitool channel setaccess 1 3 callin=on ipmi=on link=on privilege=4
ipmitool user enable 3
```

### Shell
```
#!/bin/sh
# OPENSTACK_STIIT_IPMI_STATIC_IP=192.168.10.2XX OPENSTACK_STIIT_IPMI_PASSWORD=$$PASSWORD$$ bash /tmp/ipmi_cfg.sh

set -e -x

: ${OPENSTACK_STIIT_IPMI_STATIC_IP:=192.168.10.2XX}
: ${OPENSTACK_STIIT_IPMI_PASSWORD:=$$PASSWORD$$}

ipmitool lan set 1 ipsrc static
ipmitool lan set 1 ipaddr "$OPENSTACK_STIIT_IPMI_STATIC_IP"
ipmitool lan set 1 netmask 255.255.255.0
ipmitool lan set 1 defgw ipaddr 192.168.10.1
ipmitool lan set 1 defgw macaddr 00:25:64:3c:8c:eb
ipmitool lan set 1 arp respond on
ipmitool user set password 2 "$OPENSTACK_STIIT_IPMI_PASSWORD"
ipmitool user set name 3 root
ipmitool user set password 3 "$OPENSTACK_STIIT_IPMI_PASSWORD"
ipmitool channel setaccess 1 3 callin=on ipmi=on link=on privilege=4
ipmitool user enable 3
```