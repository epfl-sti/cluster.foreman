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
use Errno;

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

Functions that have a ": PreConfigure" attribute are run before
everything else.

=cut

sub validate_dns_domain : PreConfigure {
  use Net::Domain qw(hostfqdn hostdomain);
  printf STDERR <<"DIAG", hostfqdn(), hostdomain();

This host's Fully Qualified Domain Name (FQDN) is: %s,
meaning that the DNS domain used for the hosts in the cluster will
be:

  %s

DIAG
  my $ok = undef;
  if (hostdomain eq "epfl.ch") {
    warn <<'DNS_CLASH';
WARNING: THIS IS NOT A GOOD THING.

There is (of course) already a DNS server for epfl.ch.

DNS_CLASH
    $ok = prompt_yn("Do you still want to proceed?", 0);
  } else {
    $ok = prompt_yn("Is this correct?", 1);
  }

  die <<"FIX_IT_YOURSELF" if (! $ok);

Please:
  * change the hostname with hostname -f as root;
  * edit /etc/hosts and /etc/sysconfig/network to match;
  * and re-run $0.

(The FQDN is used as a default value in so many places, that it would
be unwise to try and override it with a configure-time question.
Sorry about that!)

FIX_IT_YOURSELF
}

=head2 YAML Structure

Every top-level entry in the YAML file corresponds to a directory with
the same name in C</usr/share/foreman-installer/modules>. All modules
in the C<foreman-installer/modules> subdirectory in the sources get
grafted (using a symlink) into the foreman-installer machinery when
running this script.

Also, you can probably guess what a ": PostConfigure" annotation is for.

=cut

sub symlink_modules : PostConfigure {
  my $foreman_installer_module_path = "/usr/share/foreman-installer/modules";
  my $src_modules_dir = "$FindBin::Bin/foreman-installer/modules";
  opendir(my $dirhandle, $src_modules_dir) ||
    die "can't opendir $src_modules_dir: $!";
  foreach my $subdir (readdir($dirhandle)) {
    next if ($subdir eq "." or $subdir eq "..");
    next unless -d (my $src_module_dir = "$src_modules_dir/$subdir");
    my $symlink = "$foreman_installer_module_path/$subdir";
    warn "Creating symlink $symlink => $src_module_dir\n";
    unless (symlink($src_module_dir, $symlink)) {
      die "symlink($src_module_dir, $symlink): $!" unless $! == Errno::EEXIST;
    }
  }
  closedir($dirhandle);
  warn "\n";
}

sub foreman_provisioning__interface : ToYaml { private_interface }
sub foreman_provisioning__domain_name: ToYaml{ hostdomain() }
sub foreman_provisioning__network_address: ToYaml {
  return private_interface_config()->network->addr;
}
sub foreman_provisioning__netmask: ToYaml {
  return private_interface_config()->mask;
}
sub foreman_provisioning__gateway: ToYaml { private_ip_address }
sub foreman_provisioning__dns: ToYaml : PromptUser { private_ip_address }
sub foreman_provisioning__dhcp_range: ToYaml {
  my $range = foreman_proxy__dhcp_range;
  $range =~ s/\s+/-/g;
  return $range;
}

=head3 Plugins

Plugins are an exception to the above rule: because they are listed section
C<:mapping:> of file /etc/foreman/foreman-installer.yaml, their
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

=head2 C<epflsti> module

The C<epflsti> section in /etc/foreman/foreman-installer.yaml is used
for bona fide Puppet parameters for the like-named module, but also to
persist all the interactive answers to "PromptUser" functions that
don't have a "ToYaml" place of persistence of their own (see details
in L<GenerateAnswersYaml>),

=cut

sub epflsti__src_path : ToYaml { $FindBin::Bin }

=head2 server_environments

Hijacked so that foreman-installer doesn't create (and re-create)
/etc/puppet/environments (we want a symlink to our source tree here).

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

memoize('network_configs');
sub network_configs {
  my %network_configs;
  local *IP_ADDR;
  open(IP_ADDR, "ip addr |");
  my $current_interface;
  while(<IP_ADDR>) {
    if (m/^\d+: (\S+):/) {
      $current_interface = $1;
    } elsif (m|inet ([0-9.]+/[0-9]+)|) {
      $network_configs{$current_interface} = NetAddr::IP::Lite->new($1);
    }
  }
  close(IP_ADDR);
  return %network_configs;
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
