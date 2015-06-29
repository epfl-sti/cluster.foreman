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
use GenerateAnswersYaml;
use NetAddr::IP::Lite;

=head1 HACKING

This script is very easy to hack. For instance, functions that have a
": ToYaml" annotation return the value for a YAML configuration item,
whose path is deducted from the function name. For instance,

   sub foreman_proxy__tftp_servername : ToYaml  { ... }

computes the value for the C<tftp_servername> entry in C<foreman_proxy>.

Take a look at lib/GenerateAnswersYaml.pm for more about ToYaml and
other function decorations.

=cut

sub foreman_proxy__tftp_severname : ToYaml    { private_ip_address() }
sub foreman_proxy__dhcp_gateway : ToYaml      { private_ip_address() }
sub foreman_proxy__dhcp_nameservers : ToYaml  { private_ip_address() }
sub foreman_proxy__dns_interface : ToYaml    { private_interface() }
sub foreman_proxy__dhcp_interface : ToYaml   { private_interface() }

=pod

Booleans per se don't really exist in Perl. In order to pass Booleans
to Ruby, one uses "true" and "false" as strings.

=cut

sub foreman_proxy__tftp: ToYaml    { "true" }
sub foreman_proxy__dhcp: ToYaml    { "true" }
sub foreman_proxy__dns: ToYaml     { "true" }
sub foreman_proxy__bmc: ToYaml     { "true" }

sub foreman_proxy__bmc_default_provider: ToYaml { "ipmitool" }

sub private_ip_address : PromptUser {
  my %interfaces_and_ips = physical_interfaces_and_ips();
  my @private_ips = sort { is_rfc1918_ip($b) <=> is_rfc1918_ip($a) }
    (values %interfaces_and_ips);
  return $private_ips[0];
}

# Foreman is running inside Docker, where the network is ad-hoc:
sub private_interface { return "eth0" }

sub foreman_proxy__dhcp_range : ToYaml : PromptUser {
  my $ip = private_ip_address();
  # We might want to be smarter here.
  my $net = $ip; $net =~ s/\.[0-9]+$//;
  my $begin_dhcp_range = "$net.32";
  my $end_dhcp_range = "$net.127";
  return "$begin_dhcp_range $end_dhcp_range";
}

sub foreman_proxy__dns_reverse : ToYaml : PromptUser {
  my @arpa = (reverse(split m/\./, private_ip_address()), qw(in-addr arpa));
  shift @arpa;
  return join(".", @arpa);
}

sub foreman_proxy__dns_forwarders : ToYaml {
  [qw(128.178.15.227 128.178.15.228)]
}


=head1 FIXED CONFIGURATION

Here we document a number of special-purpose settings that oil some
cogs or others.

=head2 puppet → server

Set to true, so that foreman-installer wrangles the puppetmaster,
including its CA.

=head2 foreman_proxy → puppetca

Set to true, so that you can later sign certificates from the Foreman
web UI.

=cut

sub puppet__server : ToYaml { "true" }

sub foreman_proxy__puppetca : ToYaml { "true" }

=head2 puppet → server_environments

Set to the empty list so that foreman-installer doesn't try to create
/etc/puppet/environments and its subdirectories (we want a symlink to
our source tree here instead).

=cut

sub puppet__server_environments : ToYaml { [] }

=head2 I<>

=head1 UTILITY FUNCTIONS

A number of helper functions are available for calling from the magic
functions with attributes.

=cut

sub interfaces_and_ips {
  my %network_configs = network_configs();
  return map { ($_, $network_configs{$_}->addr) } (keys %network_configs);
}

sub physical_interfaces_and_ips {
  my %interfaces_and_ips = interfaces_and_ips();
  my %physical_interfaces_and_ips;
  while(my ($iface, $ip) = each %interfaces_and_ips) {
    if (is_physical_interface($iface)) {
      $physical_interfaces_and_ips{$iface} = $ip;
    }
  }
  return %physical_interfaces_and_ips;
}

memoize('network_configs');
sub network_configs {
  my %network_configs;
  my %bridge_members;
  local *IP_ADDR;
  open(IP_ADDR, "ip addr |");
  my $current_interface;
  while(<IP_ADDR>) {
    if (m/^\d+: (\S+):/) {
      $current_interface = $1;
      if (m/master (\S+)/) {
        push @{$bridge_members{$1}}, $current_interface;
      }
    } elsif (m|inet ([0-9.]+/[0-9]+)|) {
      # In case of multiple IPs for the same interface (i.e., aliases),
      # keep only the first one.
      $network_configs{$current_interface} ||= NetAddr::IP::Lite->new($1);
    }
  }

  foreach my $bridged_if (keys %bridge_members) {
    my @real_interfaces = grep {is_physical_interface($_)}
      (@{$bridge_members{$bridged_if}});
    if ((@real_interfaces == 1) and
          exists $network_configs{$bridged_if}) {
      $network_configs{$real_interfaces[0]} = delete $network_configs{$bridged_if};
    }
  }

  return %network_configs;
}

sub is_physical_interface {
  my ($iface_name) = @_;
  my $sysfs_link = "/sys/class/net/$iface_name";
  if (-l $sysfs_link) {
    return (readlink($sysfs_link) !~ m|devices/virtual|);
  } elsif ($iface_name =~ m/^(vir|docker|tun|tap|veth)/) {
    return 0;
  } elsif ($iface_name =~ m/^(en|wlan|wifi|eth)/) {
    return 1;
  } else {
    die "Unable to guess whether $iface_name is a physical interface";
  }
}

sub private_interface_config {
  my %network_configs = network_configs();
  return $network_configs{private_interface()};
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

=pod

All the magic happens in the L<GenerateAnswersYaml> module.

=cut

GenerateAnswersYaml::Generate();
