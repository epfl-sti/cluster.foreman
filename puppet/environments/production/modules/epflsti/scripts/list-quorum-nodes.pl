#!/usr/bin/perl -w

use strict;

=head1 NAME

list-quorum-nodes.pl - As it says on the tin

=head1 SYNOPSIS

  list-quorum-nodes.pl [ -o <outputfile> ]

=head1 DESCRIPTION

List all hosts with Hammer and feed their names through /etc/puppet/node.rb
to figure out which have $epflsti::is_quorum_node set.

=cut

use Getopt::Long;
use Carp qw(carp);

# Attempt to save stderr somewhere - No biggie if that fails
open(STDERR, "> /var/log/puppet/list-quorum-nodes.log");

sub logmsg {
  my $now = localtime(time);
  carp "[$now] $_[0]";
}

logmsg "Running " . join(" ", @ARGV);

if (! defined $ENV{HOME}) {
  $ENV{HOME} = "/root";
}

do {
  open(U_CAN_TOUCH_THIS,
     "hammer --output csv host list --per-page 1000 |" .
       " sort |");
} or die "Stop! No hammertime: $!";

# Redirect only now, so that the file doesn't get created in case of failure
our $outputfile;
GetOptions("o=s" => sub {
  (undef, $outputfile) = @_;
  logmsg "Redirecting to $outputfile";
  open(STDOUT, ">", $outputfile) or
    die "Cannot open $outputfile for writing: $!";
});

END {
  unlink($outputfile) if ($? && $outputfile);
}

while(<U_CAN_TOUCH_THIS>) {
  chomp;
  next if m/^Id,/;  # Header line
  my (undef, $hostname) = split m/,/;

  my $node_rb_command = "/etc/puppet/node.rb $hostname |";
  open(NODE_RB, $node_rb_command) or
    die "Cannot run $node_rb_command: $!";
  while(<NODE_RB>) {
    chomp;
    if (m/is_quorum_node: true/) {
      print "$hostname\n";
      last;
    }
  }
  while(<NODE_RB>) {}; close(NODE_RB);
}

close(STDOUT) or die "Cannot close: $!";
exit 0;
