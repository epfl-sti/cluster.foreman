#masq

####Table of Contents

1. [Overview](#overview)
2. [Module Description - What the module does and why it is useful](#module-description)
3. [Usage - Configuration options and additional functionality](#usage)
4. [Limitations - OS compatibility, etc.](#limitations)
5. [Development - Guide for contributing to the module](#development)

##Overview

Configures a machine with masquerading, allowing it to act as a NAT
router for other machines

##Module Description

I wrote this module to configure instances as NAT for use inside Amazon
VPC, but this could be used anywhere you want masquerading.

##Setup

##Usage

This module uses the Puppetlabs firewall module to add the masquerading
rules.

As a minimum you need to add:

```
class { 'firewall': }
class { 'masq': }
```

##Limitations

Linux specific

##Development

Please submit pull requests to github -
https://github.com/BashtonLtd/puppet-masq
