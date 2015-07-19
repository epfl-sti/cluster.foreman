#!/usr/bin/env perl

use strict;
use warnings;

=head1 NAME

configure.pl - Your friendly configure script

=head1 SYNOPSIS

  ./configure.pl

=head1 DESCRIPTION

This script computes key configuration values for Foreman, and uses
them to prepare a foreman-installer-answers.yaml file.

=head1 OPTIONS

To see the list of all options, try

  ./configure.pl --help

=cut

use Memoize;
use FindBin; use lib "$FindBin::Bin/lib";
use EPFLSTI::Foreman::Configure;
use NetAddr::IP::Lite;

=head1 HACKING

This script is very easy to hack. For instance, functions that have a
": ToYaml" annotation return the value for a YAML configuration item,
whose path is deducted from the function name. For instance,

   sub foreman_proxy__tftp_servername : ToYaml  { ... }

computes the value for the C<tftp_servername> entry in C<foreman_proxy>.

Take a look at lib/EPFLSTI/Foreman/Configure.pm for more
about ToYaml and other function decorations.

=cut

sub foreman_proxy__tftp_severname : ToYaml    { puppetmaster_vip() }
sub foreman_proxy__dhcp_gateway : ToYaml      { gateway_vip() }
sub foreman_proxy__dhcp_nameservers : ToYaml  { dns_vip() }

=pod

Booleans per se don't really exist in Perl. In order to pass Booleans
to Ruby, one uses "true" and "false" as strings.

=cut

sub foreman_proxy__tftp: ToYaml    { "true" }
sub foreman_proxy__dhcp: ToYaml    { "true" }
sub foreman_proxy__dns: ToYaml     { "true" }
sub foreman_proxy__bmc: ToYaml     { "true" }

sub foreman_proxy__bmc_default_provider: ToYaml { "ipmitool" }

sub foreman_proxy__dns_forwarders : ToYaml {
  [qw(128.178.15.227 128.178.15.228)]
}

=head1 VIP CONFIGURATION

B<configure.pl> reserves a number of so-called Virtual IPs (VIPs),
which belong to a service, rather than a physical host; in case of a
failover, services and their VIPs are allowed to move about in the
cluster.

In the case of a VIP for a Docker container, the way to do that is
bridging. Thus, C<configure.pl> expects to find the physical interface
for the cluster's internal network to be part of a bridge (which under
Linux bears the IP address in the C<ifconfig> or C<ip addr show>
sense, rather than the physical interface; see
https://unix.stackexchange.com/questions/86056/).

=cut

sub physical_internal_ip : PromptUser {
  my %network_configs = network_configs();
  my @phybridges = grep {
    my $iface = $network_configs{$_};
    (@{$iface->{ips}} >= 1) &&
      (grep {is_physical_interface($_)} @{$iface->{bridged}});
  } (keys %network_configs);
  if (@phybridges) {
    return $phybridges[0]->{ips}->[0];
  } else {
    warn <<GRIPE;
WARNING: Could not detect a bridge tied to a physical interface.

In order for Docker VIPs (most prominently, the Puppetmaster's) to work,
you will need to:
   1. set up a bridge (e.g. brctl addbr ethbr4),
   2. bridge the internal physical interface to it (e.g. brctl addif ethbr4 eth1),
   3. unset the host's internal IP address on the physical interface, and
      set it on the bridge using ifconfig or ip addr.

Trying to resume configuration with guesswork.

GRIPE
    my @private_ips = sort { is_rfc1918_ip($b) <=> is_rfc1918_ip($a) }
      (map {@{$_->{ips}}} (values %network_configs));
    return $private_ips[0];
  }
}

sub gateway_vip : PromptUser {
  my @quad = split m/\./, physical_internal_ip();
  $quad[3] = 254;
  return join(".", @quad);
}

sub puppetmaster_vip : PromptUser {
  my @quad = split m/\./, gateway_vip();
  $quad[3] = 225;
  return join(".", @quad);
}

sub dns_vip : PromptUser {
  my @quad = split m/\./, gateway_vip();
  $quad[3] -= 1;
  if ($quad[3] eq 0) {
    $quad[3] = 254;
  }
  return join(".", @quad);
}

memoize('network_configs');
sub network_configs {
  my %network_configs;
  local *IP_ADDR;
  open(IP_ADDR, "ip addr |");
  my ($current_interface, $current_interface_name);
  while(<IP_ADDR>) {
    if (m/^\d+: (\S+):/) {
      $current_interface_name = $1;
      $current_interface = ($network_configs{$1} ||= {name => $1});
      if (m/master (\S+)/) {
        my $master_interface = ($network_configs{$1} ||= { name => $1});
        push @{$master_interface->{bridged}}, $current_interface_name;
      }
    } elsif (m|inet ([0-9.]+/[0-9]+)|) {
      push @{$current_interface->{ips}}, NetAddr::IP::Lite->new($1);
    }
  }

  return %network_configs;
}

sub interface_type {
  my ($iface_name) = @_;
  my $sysfs_link = "/sys/class/net/$iface_name";
  if (-l $sysfs_link) {
    if  (readlink($sysfs_link) !~ m|devices/virtual|) {
      return "physical";
    } elsif (-d "$sysfs_link/bridge") {
      return "bridge";
    } else {
      return "virtual";
    }
  } elsif ($iface_name =~ m/^(vir|tun|tap|veth)/) {
    return "virtual";
  } elsif ($iface_name =~ m/br|docker/) {
    return "bridge",
  } elsif ($iface_name =~ m/^(en|wlan|wifi|eth)/) {
    return "physical";
  } else {
    die "Unable to guess whether $iface_name is a physical interface";
  }
}

sub is_rfc1918_ip {
  my ($byte1, $byte2) = split m/\./, shift;
  # Actually returns a "credibility score", 192.168 coming first:
  if ("$byte1.$byte2" == "192.168") {
    return 3;
  } elsif ($byte1 eq "10") {
    return 2;
  } elsif ($byte1 == 172 && $byte2 >= 16 && $byte2 <= 31) {
    return 1;
  } else {
    return 0;
  }
}



=head1 FIXED CONFIGURATION

Here we document a number of special-purpose settings that oil some
cogs or others.

=head2 puppet → server

Set to true, so that foreman-installer wrangles the puppetmaster,
including its CA.

=cut

sub puppet__server : ToYaml { "true" }

=head2 puppet → server_environments

Set to the empty list so that foreman-installer doesn't try to create
/etc/puppet/environments and its subdirectories (we want a symlink to
our source tree here instead).

=cut

sub puppet__server_environments : ToYaml { [] }

=head2 foreman_proxy → dns_interface

=head2 foreman_proxy → dhcp_interface

Foreman is running inside Docker, where the network is ad-hoc; so this
is always eth1 (eth0 being reserved to reach the Internet through
Docker's NAT).

=cut

sub foreman_proxy__dns_interface : ToYaml { "eth1" }
sub foreman_proxy__dhcp_interface : ToYaml { "eth1" }


=head1 UTILITY FUNCTIONS

A number of helper functions are available for calling from the magic
functions with attributes.

=cut

=pod

All the magic happens in the L<EPFLSTI::Foreman::Configure> module.

=cut

EPFLSTI::Foreman::Configure->generate();
