#!/usr/bin/env perl

use strict;
use warnings;

=head1 NAME

I<create-facts-yaml.pl> - Print YAMLized facts of this host to standard output

=head1 SYNOPSIS

  create-facts-yaml.pl

=head1 DESCRIPTION

I<create-facts-yaml.pl> prints the Puppet-style YAMLized facts of the
host it is running on to standard output. This is used by the
I<foreman_provisionning> foreman-installer plugin to create
/var/lib/puppet/yaml/facts/$(hostname -f).yaml, which in turn is
uploaded into Foreman so that one can run the wizard (see
setup-provisioning.rb in the same directory)

Basically, this just wraps the output of C<facter -y> to mimic a
"real" Puppet-style YAML fact file.

=cut

open(FACTER, "facter -y |") or
  die "Cannot run facter -y: $!";

$_ = <FACTER>;
unless (defined && m/^---/) {
  warn $_ if defined;
  while(<FACTER>) { warn $_; }
  die <<"BAIL";
Unable to read any output from facter -y, check messages above if any.
BAIL
}

print <<HEADER;
--- !ruby/object:Puppet::Node::Facts
  values:
HEADER

while(<FACTER>) { print "    $_" }


