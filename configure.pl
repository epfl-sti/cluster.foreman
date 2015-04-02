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
thereafter will complete the process.

foreman-installer is designed to be fine if run multiple times, and
configure.pl respects that; it should also be fine to run configure.pl
multiple times, even after foreman-installer has run.

=head1 OPTIONS

To see the list of all options, try

  ./configure.pl --help

=head1 HACKING

This script is very easy to hack.

=over 4

=item *

Functions that have a ": ToYaml" annotation return the value for a
YAML configuration item, whose path is deducted from the function name.
For instance,

   sub foreman_proxy__tftp_severname : ToYaml  { ... }

computes the value for the C<tftp_servername> entry in C<foreman_proxy>.

=cut

use Memoize;
use Net::Domain qw(hostname);
use FindBin; use lib "$FindBin::Bin/lib";
use GenerateAnswersYaml;

sub foreman_proxy__tftp_severname : ToYaml    { private_ip_address() }
sub foreman_proxy__dhcp_gateway : ToYaml      { private_ip_address() }
sub foreman_proxy__dhcp_nameservers : ToYaml  { private_ip_address() }

sub foreman_proxy__dns_zone : ToYaml { return dns_domain() }
sub foreman__servername : ToYaml {
  return fully_qualified_domain_name()
}

=pod

One can override the default path deduction by passing parameters to
the ToYaml annotation, e.g.

   sub foreman_url : ToYaml("foreman", "foreman_url")  { ... }

=cut

sub foreman_url : ToYaml("foreman", "foreman_url") {
  return "https://" . fully_qualified_domain_name();
}

=item *

Functions that have a ": PromptUser" attribute compute a value, and
leave the option for the user to override it interactively.

=cut

sub dns_domain : PromptUser { "cloud.epfl.ch" }
sub fully_qualified_domain_name : PromptUser {
  return sprintf("%s.%s", hostname(), dns_domain());
}

=back

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

sub foreman_proxy__dns_interface : ToYaml    { private_interface() }
sub foreman_proxy__dhcp_interface : ToYaml   { private_interface() }

sub foreman_proxy__dns_reverse : ToYaml : PromptUser {
  my @arpa = (reverse(split m/\./, private_ip_address()), qw(in-addr arpa));
  shift @arpa;
  return join(".", @arpa);
}

sub foreman_proxy__dns_forwarders : ToYaml {
  [qw(128.178.15.227 128.178.15.228)]
}

sub foreman_proxy__puppet_url : ToYaml { foreman_url . ":8140" }
sub foreman_proxy__template_url : ToYaml { foreman_url . ":8000" }

sub private_ip_address : PromptUser {
  my %interfaces_and_ips = interfaces_and_ips();
  my @private_ips = sort { is_rfc1918_ip($b) <=> is_rfc1918_ip($a) }
    (values %interfaces_and_ips);
  return $private_ips[0];
}

sub private_interface : PromptUser {
  my %ips_to_interfaces = reverse(interfaces_and_ips());
  return $ips_to_interfaces{private_ip_address()};
}

sub public_ip_address : PromptUser {
  use IO::Socket::INET;
  use Socket;
  my $sock = new IO::Socket::INET(
    PeerHost => "8.8.8.8", PeerPort => 80, Blocking => 0);
  my (undef, $myaddr) = sockaddr_in(getsockname($sock));
  return inet_ntoa($myaddr);
}

# Let foreman-installer know that we want our own
# foreman-installer/modules/openstacksti to be part of its to-do list.
sub openstacksti : ToYaml { return {} }

# Same effect as --enable-foreman-plugin-discovery
#   --foreman-plugin-discovery-install-images=true etc.

=pod

The rest is cuisine.

=cut

memoize('interfaces_and_ips');
sub interfaces_and_ips {
  my %interfaces_and_ips;
  local *IP_ADDR;
  open(IP_ADDR, "ip addr |");
  my $current_interface;
  while(<IP_ADDR>) {
    if (m/^\d+: (\S+):/) {
      $current_interface = $1;
    } elsif (m/inet ([0-9.]+)/) {
      $interfaces_and_ips{$current_interface} = $1;
    }
  }
  close(IP_ADDR);
  return %interfaces_and_ips;
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

GenerateAnswersYaml::Generate();
