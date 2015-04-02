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

use FindBin; use lib "$FindBin::Bin/lib";
use GenerateAnswersYaml;

sub foreman_plugin_discovery : ToYaml {
  return {
    tftp_root => "/var/lib/tftpboot",
    image_name => "fdi-image-latest.tar",
    source_url => "http://downloads.theforeman.org/discovery/releases/latest/",
    install_images => 1
  }
}

sub public_ip_address : PromptUser {
  use IO::Socket::INET;
  use Socket;
  my $sock = new IO::Socket::INET(PeerHost => "8.8.8.8", PeerPort => 80, Blocking => 0);
  my (undef, $myaddr) = sockaddr_in(getsockname($sock));
  return inet_ntoa($myaddr);
}

GenerateAnswersYaml::Generate(\@ARGV);
