#!/usr/bin/env perl

use strict;
use warnings;

=head1 NAME

configure.pl - Your friendly configure script

=head1 SYNOPSIS

  ./configure.pl

=head1 DESCRIPTION

This script computes some of the values for
/etc/foreman/foreman-installer-answers.yaml. Running foreman-installer
thereafter will make use of the values in that file.

foreman-installer is designed to support being run multiple times, and
configure.pl follows suit; it should also be fine to run configure.pl
multiple times, even after foreman-installer has run.

=head1 OPTIONS

To see the list of all options, try

  ./configure.pl --help

=cut

use Memoize;
use FindBin; use lib "$FindBin::Bin/lib";
use GenerateAnswersYaml qw(prompt_yn);
use NetAddr::IP::Lite;
use Net::Domain qw(hostfqdn hostdomain);
use Errno;
use File::Which qw(which);

=head1 HACKING

This script is very easy to hack.

Functions that have a ": ToYaml" annotation return the value for a
YAML configuration item, whose path is deducted from the function name.
For instance,

   sub foreman_proxy__tftp_servername : ToYaml  { ... }

computes the value for the C<tftp_servername> entry in C<foreman_proxy>.

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

=pod

Functions that have a ": PromptUser" attribute compute a value, and
leave the option for the user to override it interactively or with a
command-line switch.

=cut

sub private_ip_address : PromptUser {
  my %interfaces_and_ips = physical_interfaces_and_ips();
  my @private_ips = sort { is_rfc1918_ip($b) <=> is_rfc1918_ip($a) }
    (values %interfaces_and_ips);
  return $private_ips[0];
}

# Foreman is running inside Docker, where the network is ad-hoc:
sub private_interface { return "eth0" }

sub public_ip_address : PromptUser {
  use IO::Socket::INET;
  use Socket;
  my $sock = new IO::Socket::INET(
    PeerHost => "8.8.8.8", PeerPort => 80, Blocking => 0);
  my (undef, $myaddr) = sockaddr_in(getsockname($sock));
  return inet_ntoa($myaddr);
}

=pod

Functions can also have multiple attributes.

=cut

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

=pod

C<PromptUser> can take arguments, in particular C<< validate => >> for
a validation function.

=cut

=head2 YAML Structure

Every top-level entry in the YAML file corresponds to a directory with
the same name in C</usr/share/foreman-installer/modules>. All modules
in the C<foreman-installer/modules> subdirectory in the sources get
grafted (using a symlink) into the foreman-installer machinery when
running this script.

=cut

=head3 Plugins

Plugins are an exception to the above rule: because they are listed section
C<:mapping:> of the foreman-installer-answers.yaml file, their
foreman-installer configuration is read from a different set of files. As a
consequence, only those plugins that are known to the stock foreman-installer
may be configured with configure.pl. To install and configure third-party
plugins, take a look at the 'column_view' example in
foreman-installer/modules/epflsti/manifests/init.pp

One can conveniently override the default path deduction by passing
parameters to the ToYaml annotation, e.g.

   sub discovery_config : ToYaml("foreman::plugin::discovery")  { ... }

=cut

sub discovery_config : ToYaml("foreman::plugin::discovery") {
  {
    install_images => "true",
    tftp_root => "/var/lib/tftpboot/",
  }
}

=head1 QUIRKS

Here we document a number of special-purpose settings that oil some
cogs or others.

=head2 server_environments

Hijacked so that foreman-installer doesn't create (and re-create)
/etc/puppet/environments and its subdirectories (we want a symlink to
our source tree here instead; see
foreman-installer/modules/epflsti/manifests/puppetconfig.pp).

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
  my %physical_interfaaces_and_ips;
  while(my ($iface, $ip) = each %interfaces_and_ips) {
    if (is_physical_interface($iface)) {
      $physical_interfaaces_and_ips{$iface} = $ip;
    }
  }
  return %physical_interfaaces_and_ips;
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

Finally, the magic with function attributes happens in the
L<GenerateAnswersYaml> module.

=cut

GenerateAnswersYaml::Generate();
