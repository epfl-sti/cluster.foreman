package GenerateAnswersYaml;

use strict;
use warnings;

=head1 NAME

GenerateAnswersYaml - The engine behind ../configure.pl

=cut

use Attribute::Handlers;
use Exporter;

=head2 ToYaml

Functions in ../configure.pl decorated with this attribute produce an
output in /etc/foreman/foreman-installer-answers.yaml under a path
derived from their name.

=cut

sub UNIVERSAL::ToYaml : ATTR(CODE) {
  my (undef, undef, $coderef) = @_;
  warn _function_name($coderef) . " produces YAML";
}

=head2 PromptUser

Functions in ../configure.pl decorated with this attribute prompt the
user for their return value. The return value of the function body is
used as the default.

=cut

sub UNIVERSAL::PromptUser : ATTR(CODE) {
  warn _function_name($coderef) . " is supposed to prompt the user";
}

sub _function_name {
  my ($sub_ref) = @_;
  # https://stackoverflow.com/questions/7419071/determining-the-subroutine-name-of-a-perl-code-reference
  use B qw(svref_2object);
  return svref_2object($sub_ref)->GV->NAME;
}

sub Generate {
}

1;
