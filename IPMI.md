# IPMI - Intelligent Platform Management Interface

The Intelligent Platform Management Interface (IPMI) is a set of computer interface specifications for an autonomous computer subsystem that provides management and monitoring capabilities independently of the host system's CPU, firmware (BIOS or UEFI) and operating system. IPMI defines a set of interfaces used by system administrators for out-of-band management of computer systems and monitoring of their operation. For example, IPMI provides a way to manage a computer that may be powered off or otherwise unresponsive by using a network connection to the hardware rather than to an operating system or login shell. (Source: http://en.wikipedia.org/wiki/Intelligent_Platform_Management_Interface)


## Red-Hat configuration

(Source https://lonesysadmin.net/2007/06/21/how-to-configure-ipmi-on-a-dell-poweredge-running-red-hat-enterprise-linux/)

### Getting the OS prepared:

1. Install IPMItool and the startup scripts. On Red Hat Enterprise Linux install the OpenIPMI, OpenIPMI-tools, OpenIPMI-libs, and OpenIPMI-devel packages. That will get you everything you need. There are similar packages available for other distributions (SuSE, Ubuntu, CentOS, etc.). You’ll need IPMItool on any machine you want to configure, and any machine you want to send commands from.
2. Enable the IPMI service:
```/sbin/chkconfig ipmi on```
3. Start the IPMI service, which will load the kernel modules for you:
```/sbin/service ipmi start```

### Configure the BMC for Remote Usage:

1. There are two ways to configure the BMC. You can configure it through the boot-time menu (Ctrl-E), where you can set the management password and IP address information. Or, you can configure it with ipmitool from the OS. Replace my sample IP address, gateway, and netmask with your own:
   * ```/usr/bin/ipmitool -I open lan set 1 ipaddr 192.168.40.88```
   * ```/usr/bin/ipmitool -I open lan set 1 defgw ipaddr 192.168.40.1```
   * ```/usr/bin/ipmitool -I open lan set 1 netmask 255.255.255.0```
   * ```/usr/bin/ipmitool -I open lan set 1 access on```
2. Secure the BMC, so unauthorized people can’t power cycle your machines. To do this you want to change the default SNMP community, the “null” user password, and the root user password. First, set the SNMP community, either to a random string or something you know:
```/usr/bin/ipmitool -I open lan set 1 snmp YOURSNMPCOMMUNITY```

Then set the null user password to something random. Replace CRAPRANDOMSTRING with something random and secure:
```/usr/bin/ipmitool -I open lan set 1 password CRAPRANDOMSTRING```

Last, set the root user password to something you know:
```/usr/bin/ipmitool -I open user set password 2 REMEMBERTHIS```

Double-check your settings with:
```/usr/bin/ipmitool -I open lan print 1```

### Trying it:

1. You can set an environment variable, IPMI_PASSWORD, with the password you used above. That will save some typing:
```export IPMI_PASSWORD="REMEMBERTHIS"```
   * If you use this substitute the “-a” in the following commands with a “-E”.
2. From another machine issue the following command, obviously replacing the IP with the target BMC’s IP:
```/usr/bin/ipmitool -I lan -U root -H 192.168.40.88 -a chassis power status```



## Useful commands

* List all commands
   * ```ipmitool -I lan -U root -H 128.178.48.72 -a```

* Restart server
   * ```ipmitool -I lan -U root -H 128.178.48.72 -a power reset```

* Turn server ON
   * ```ipmitool -I lan -U root -H 128.178.48.72 -a power on```

* Turn server OFF
   * ```ipmitool -I lan -U root -H 128.178.48.72 -a power off```

* Session info
   * ```ipmitool -I lan -U root -H 128.178.48.72 -a session info all```


# Infos / Doc / Resources
* [Configuring SuperMicro IPMI to use one of the LAN interfaces instead of the IPMI port?](http://serverfault.com/questions/361940/configuring-supermicro-ipmi-to-use-one-of-the-lan-interfaces-instead-of-the-ipmi)
* [Bare Metal Service Installation Guide#IPMI](http://docs.openstack.org/developer/ironic/deploy/install-guide.html#ipmi-support)
* [ipmi on CentOs](http://www.openfusion.net/linux/ipmi_on_centos)
* [7 underuser ipmitool commands](http://www.xkyle.com/7-underused-ipmitool-commands/)

## With foreman
* [Control server alim with foreman](http://www.fitzdsl.net/fr/2013/07/controlez-lalimentation-de-vos-serveurs-avec-foreman/)