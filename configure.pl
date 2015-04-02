#!/usr/bin/env perl

use strict;
use warnings;

=head1 NAME

configure.pl - Your friendly configure script

=head1 SYNOPSIS

  ./configure.pl

=head1 DESCRIPTION

This script computes reasonable default values for /etc/foreman/foreman-installer-answers.yaml,
then runs $EDITOR on it.

=cut

use Memoize;
use FindBin; use lib "$FindBin::Bin/lib";
use GenerateAnswersYaml;

sub foreman_plugin_discovery : ToYaml("foreman::plugin::discovery") {
  return {
    tftp_root => "/var/lib/tftpboot",
    image_name => "fdi-image-latest.tar",
    source_url => "http://downloads.theforeman.org/discovery/releases/latest/",
    install_images => "true"
  }
}

sub foreman_proxy__dhcp_gateway : ToYaml {
  return private_ip_address();
}

sub foreman_proxy__tftp_severname : ToYaml {
  return private_ip_address();
}

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

sub private_ip_address : PromptUser {
  my %interfaces_and_ips = interfaces_and_ips;
  my @private_ips = sort { is_rfc1918_ip($b) <=> is_rfc1918_ip($a) }
    (values %interfaces_and_ips);
  return $private_ips[0];
}

sub public_ip_address : PromptUser {
  use IO::Socket::INET;
  use Socket;
  my $sock = new IO::Socket::INET(
    PeerHost => "8.8.8.8", PeerPort => 80, Blocking => 0);
  my (undef, $myaddr) = sockaddr_in(getsockname($sock));
  return inet_ntoa($myaddr);
}

GenerateAnswersYaml::Generate();
