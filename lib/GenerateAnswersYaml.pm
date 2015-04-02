package GenerateAnswersYaml;

use strict;
use warnings;

=head1 NAME

GenerateAnswersYaml - The engine behind ../configure.pl

=head1 DESCRIPTION

=cut

use base 'Exporter'; our @EXPORT = qw(debug);

use Attribute::Handlers;
use Getopt::Long;
use YAML::Tiny;

sub debug {
  warn @_;
}

=head2 ToYaml

Functions in ../configure.pl decorated with this attribute produce an
output in /etc/foreman/foreman-installer-answers.yaml under a path
derived from their name.

=cut

sub UNIVERSAL::ToYaml : ATTR(CODE) {
  debug(_function_name($_[2]) . " produces YAML");
  GenerateAnswersYaml::_MagicSub->decorate(@_);
}

=head2 Flag

There's a flag to override (the default value of) this function.

The flag name is derived from the name of the function by folding to
lowercase and replacing underscores with dashes.

=cut

sub UNIVERSAL::Flag : ATTR(CODE) {
  debug(_function_name($_[2]) . "? There's a flag for that!");
  GenerateAnswersYaml::_MagicSub->decorate(@_);
}

=head2 PromptUser

Functions in ../configure.pl decorated with this attribute prompt the
user for their return value. The return value of the function body is
used as the default.

C<PromptUser> implies L</Flag>; if the flag is present on the command
line, then the user is I<not> prompted.

=cut

sub UNIVERSAL::PromptUser : ATTR(CODE) {
  debug(_function_name($_[2]) . " is supposed to prompt the user");
  GenerateAnswersYaml::_MagicSub->decorate(@_);
}

sub _prompt_user {
  my ($question, $default) = @_;
  print "$question [$default]:\n";
  my $answer = <>;
  if ($answer eq "") {
    return $default;
  } elsif ($answer eq ".") {
    return "";  # OpenSSL-style
  } else {
    return $answer;
  }
}

sub _function_name {
  my ($sub_ref) = @_;
  # https://stackoverflow.com/questions/7419071/determining-the-subroutine-name-of-a-perl-code-reference
  use B qw(svref_2object);
  return svref_2object($sub_ref)->GV->NAME;
}


=head2 Generate

Perform the update on /etc/foreman/foreman-installer-answers.yaml.

=cut

sub Generate {
  my @persistent = GenerateAnswersYaml::_MagicSub->all_with_attribute("ToYaml");
  foreach my $promptable (GenerateAnswersYaml::_MagicSub->all_with_attribute("PromptUser")) {
    my $already_accounted_for = $promptable->{has_ToYaml};
    push @persistent, $promptable unless $already_accounted_for;
  }
  my $yaml = YAML::Tiny->new;
  for (@persistent) {
    push @$yaml, {$_->yaml_key => $_->value() };
  }
  print $yaml->write_string;  # XXX
}

=head1 GenerateAnswersYaml::_MagicSub

Models a sub decorated with L</ToYaml>, L</PromptUser> and/or
L</Flag>.

=cut

package GenerateAnswersYaml::_MagicSub;

use vars qw(%known);

sub _find {
  my ($class, $coderef) = @_;
  my $name = GenerateAnswersYaml::_function_name($coderef);
  return ($known{$name} ||=
            bless { name => $name, code_orig => $coderef }, $class);
}

sub decorate {
  my ($class, undef, $glob, $coderef, $attr) = @_;
  my $self = $class->_find($coderef);
  $self->{"has_$attr"} = 1;
  unless ($attr eq "ToYaml") {
    # Set one and the same wrapper for all annotations that require one.
    # This guarantees that said annotations are commutative.
    $glob = sub { $self->value() };
  }
}

sub all_with_attribute {
  my ($class, $attribute) = @_;
  return grep { $_->{"has_$attribute"} } (values %known);
}

sub yaml_key {
  my ($self) = @_;
  if ($self->{has_ToYaml}) {
    my $key = lc($self->{name});
    $key =~ s/_/::/g;
    return $key;
  } elsif ($self->{has_PromptUser}) {
    return "openstack-sti::" . $self->{name};
  } else {
    die "$self->{name} is not persistent";
  }
}

sub flag_name {
  my ($self) = @_;
  my $flag = lc($self->{name});
  $flag =~ s/_/-/g;
  return $flag;
}

sub human_name {
  my ($self) = @_;
  my $flag = ucfirst($self->{name});
  $flag =~ s/_/ /g;
  return $flag;
}

sub getopt_spec {
  my ($class) = @_;
  return map {
    my $self = $_;
    ($self->flag_name . "=s") => sub { $self->set_from_flag(@_) }
  } (values %known);
}

sub set_from_flag {
  my ($self, $flagval) = @_;
  $self->{flag_value} = $flagval;
}

sub value {
  my ($self) = @_;
  if ($self->{flag_value}) {
    return $self->{flag_value};
  } elsif ($self->{interactive_value}) {
    return $self->{interactive_value};
  } elsif ($self->{has_PromptUser}) {
    return ($self->{interactive_value} = GenerateAnswersYaml::_prompt_user(
      $self->human_name, $self->{code_orig}->()));
  } else {
    # Flag sub absent from command line
    return $self->{code_orig}->();
  }
}

1;
