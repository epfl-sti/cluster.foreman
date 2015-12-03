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

use autodie;
use Memoize;
use List::Util qw(max);
use FindBin; use lib "$FindBin::Bin/lib";
use EPFLSTI::Foreman::Configure;
use NetAddr::IP::Lite;

foreach my $command (qw(brctl docker)) {
  system("which $command >/dev/null 2>&1") &&
    die <<"MESSAGE";
Cannot find $command, please install it first.
MESSAGE
}

=head1 HACKING

This script is very easy to hack. For instance, functions that have a
": ToYaml" annotation return the value for a YAML configuration item,
whose path is deducted from the function name. For instance,

   sub foreman_proxy__tftp_servername : ToYaml  { ... }

computes the value for the C<tftp_servername> entry in C<foreman_proxy>.

Take a look at lib/EPFLSTI/Foreman/Configure.pm for more
about ToYaml and other function decorations.

=cut

sub foreman_proxy__tftp_servername : ToYaml    { puppetmaster_vip() }
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

=head1 NETWORK ADDRESS PLANNING AND VIP CONFIGURATION

B<configure.pl> reserves a number of so-called Virtual IPs (VIPs),
which belong to a service, rather than a physical host; in case of a
failover, services and their VIPs are allowed to move about in the
cluster.

In the case of a VIP for a Docker container, the way to do that is
to set up a bridge, which C<configure.pl> offers to take care of for you.

C<configure.pl> will also take care of setting up an IPv4 address plan.

=cut

sub physical_internal_bridge :
  ToYaml : PromptUser(validate => \&maybe_configure_internal_bridge) {
  my %network_configs = network_configs();
  my @phybridges = grep {
    my $iface = $network_configs{$_};
    (@{$iface->{ips} || []} >= 1) &&
      (grep {interface_type($_) eq "physical"} (@{$iface->{bridged} || []}));
  } (keys %network_configs);
  if (@phybridges) {
    return $phybridges[0];
  } else {
    return "ethbr4";
  }
}

sub maybe_configure_internal_bridge {
  my ($bridgenameref) = @_;
  my $bridgename = $$bridgenameref;
  my %network_configs = network_configs();
  return if exists $network_configs{$bridgename};

  my $internal_iface = physical_internal_interface();
  warn <<"GRIPE";
WARNING: $bridgename is not configured.

In order for Docker VIPs to be reachable, we need to bridge them to
the physical interface for the internal network.

Shall I set up $bridgename and bridge it with $internal_iface now?

GRIPE

  sub auto_setup_bridge : PromptUser(question => "Set up bridge automatically?") {
    return "y";
  }
  return if (auto_setup_bridge =~ m/^n/i);

  system("set -x; brctl addbr $bridgename");
  system("set -x; brctl addif $bridgename $internal_iface");
  # Move over all IP and aliases from pysical to bridge:
  # https://unix.stackexchange.com/questions/86056/
  foreach my $ip (@{$network_configs{$internal_iface}->{ips}}) {
    system("set -x; ip addr del $ip dev $internal_iface");
    system("set -x; ip addr add $ip dev $bridgename");
  }
  # Also move over the routes:
  local *ROUTES;
  open(ROUTES, "ip route show dev $internal_iface |");
  while(<ROUTES>) {
    next if m/169.254/;
    next unless my ($route) = m|^(\d+\.\d+\.\d+\.\d+/\d+)|;
    system("set -x; ip route del $route dev $internal_iface");
    system("set -x; ip route add $route dev $bridgename");
  }
  close(ROUTES);
}

sub physical_internal_interface : PromptUser {
  my %network_configs = network_configs();
  my $rfc1918_score_of_interface = sub {
    my ($iface) = @_;
    my $score = max(map {rfc1918_score($_)} @{$iface->{ips}}) // -1;
    warn("$iface->{name} has score $score");
    return $score;
  };
  my @physical_interfaces = sort {
    $rfc1918_score_of_interface->($b) <=> $rfc1918_score_of_interface->($a)
  } (grep {interface_type($_->{name}) eq "physical"} (values %network_configs));
  return if ! @physical_interfaces;
  return $physical_interfaces[0]->{name};
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


sub main_netmask : ToYaml : PromptUser { 24 }

sub foreman_proxy__dhcp_range : ToYaml : PromptUser {
  my $ip = puppetmaster_vip();
  # We might want to be smarter here.
  my $net = $ip; $net =~ s/\.[0-9]+$//;
  my $begin_dhcp_range = "$net.129";
  my $end_dhcp_range = "$net.191";
  return "$begin_dhcp_range $end_dhcp_range";
}


sub dns_vip : PromptUser {
  my @quad = split m/\./, gateway_vip();
  $quad[3] -= 1;
  if ($quad[3] eq 0) {
    $quad[3] = 254;
  }
  return join(".", @quad);
}

sub ipmi_vip : ToYaml : PromptUser { "192.168.10.253" }
sub ipmi_netmask : ToYaml : PromptUser { 24 }


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

# Returns a score of how credible it is that this IP is the internal IP
# for the provisioning network.
sub rfc1918_score {
  my ($byte1, $byte2) = split m/\./, shift;
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

=head2 puppet → agent

Set to false. We don't want the Puppetmaster-in-Docker to manage itself.

=cut

sub puppet__agent : ToYaml { "false" }

=head2 puppet → server_parser

Set to "future", to enable the future parser (see
L<https://puppetlabs.com/blog/puppet-3-2-introduces-an-experimental-parser-and-new-iteration-features>)

=cut

sub puppet__server_parser : ToYaml { "future" }

=head2 puppet → server_environments

Set to the empty list so that foreman-installer doesn't try to create
/etc/puppet/environments and its subdirectories (we want a symlink to
our source tree here instead).

=cut

sub puppet__server_environments : ToYaml { [] }

=head2 puppetdb

Enabled, and set to share the same PostgreSQL as Foreman.

=cut

sub puppetdb : ToYaml {
  return {
    ssl_listen_address => '0.0.0.0',
    manage_dbserver => "false"
  }
}

=head2 foreman_proxy → dns_interface

=head2 foreman_proxy → dhcp_interface

Foreman is running inside Docker, where the network is ad-hoc; so this
is always eth1 (eth0 being reserved to reach the Internet through
Docker's NAT).

=cut

sub foreman_proxy__dns_interface : ToYaml { "eth1" }
sub foreman_proxy__dhcp_interface : ToYaml { "eth1" }

=head2 foreman::cli

Set to a true value so that foreman-installer sets up hammer

=cut

sub foreman_cli : ToYaml("foreman::cli") { {} }


=head1 UTILITY FUNCTIONS

A number of helper functions are available for calling from the magic
functions with attributes.

=cut

=pod

All the magic happens in the L<EPFLSTI::Foreman::Configure> module.

=cut

EPFLSTI::Foreman::Configure->generate();
