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
use Tie::IxHash;

# Both of these can be changed with L</parse_argv>.

our $target_file = "/etc/foreman/foreman-installer-answers.yaml";

sub debug {
  warn @_ if $ENV{DEBUG};
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
  chomp($answer);
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

=head2 get_yaml_state

Return the entire state as a single YAML string.

=cut

sub get_yaml_state {
  tie(my %yaml, "Tie::IxHash");
  return YAML::Tiny->new(\%yaml)->write_string;
}

=head2 parse_argv

Change global state and values for options from the command-line flags.

=cut

sub parse_argv {
  die "Bad flags" unless GetOptions(
    "target-file=s" => sub { my ($opt, $value) = @_; $target_file = $value },
    GenerateAnswersYaml::_MagicSub->getopt_spec);
}

=head2 Generate

Perform the update on /etc/foreman/foreman-installer-answers.yaml.

=cut

sub Generate {
  parse_argv;
  if (-f $target_file) {
    warn "$target_file already exists.\n\n";
  }
  my $state = GenerateAnswersYaml::_YamlState->load($target_file);
  $state->compute_all;
  do {
    open(OUT, ">", "$target_file.new") &&
      (print OUT $state->dump) &&
      close(OUT)
  } or die "Cannot write to $target_file.new: $!";
  rename("$target_file.new", $target_file) or
    die "Cannot rename $target_file.new to $target_file: $!";
  warn "Configuration updated in $target_file.\n\n";
}

=head1 GenerateAnswersYaml::_YamlState

Models the entire state of the script.

=cut

package GenerateAnswersYaml::_YamlState;

sub load {
  my ($class, $filename) = @_;
  die unless defined $filename;
  my $state;
  if (! $filename) {
    tie(my %objects, "Tie::IxHash");
    $state = \%objects;
  } else {
    # Not sure how to keep order when loading, oh well
    $state = YAML::Tiny->read($filename)->[0];
    foreach my $magicsub (GenerateAnswersYaml::_MagicSub->all) {
      next unless ($magicsub->{has_PromptUser});
      my $key = $magicsub->yaml_key;
      next unless exists $state->{$key};
      my $saved_value = $state->{$key};
      $magicsub->set_default_from_yaml($saved_value);
    }
  }
  return bless {
    state => $state
  }, $class;
}

sub update {
  my ($self, $magicsub) = @_;
  $self->{state}->{$magicsub->yaml_key} = $magicsub->value();
}

sub compute_all {
  my ($self) = @_;
  my @all = GenerateAnswersYaml::_MagicSub->all;
  foreach my $magicsub (@all) {
    if ($magicsub->{has_ToYaml}) {
      $self->update($magicsub);
    }
  }
  foreach my $magicsub (@all) {
    if ($magicsub->{has_PromptUser} && ! $magicsub->{has_ToYaml}) {
      $self->update($magicsub);
    }
  }
}

sub dump {
  my ($self) = @_;
  if ($ENV{DEBUG}) {
    require Data::Dumper;
    GenerateAnswersYaml::debug(Data::Dumper::Dumper($self->{state}));
  }
  my $yaml = YAML::Tiny->new([$self->{state}])->write_string;
  # Mimic the real foreman-installer format even though I'm not sure
  # how right that is:
  $yaml =~ s/---\n-\n/---\n/;
  # This, on the other hand, would most likely throw Ruby off the
  # rails (pun intended) if we didn't do it.
  $yaml =~ s/'true'$/true/gm;
  $yaml =~ s/'false'$/false/gm;
  return $yaml;
}

=head1 GenerateAnswersYaml::_MagicSub

Models a sub decorated with L</ToYaml>, L</PromptUser> and/or
L</Flag>.

=cut

package GenerateAnswersYaml::_MagicSub;

use vars qw(%known);
tie(%known, "Tie::IxHash");

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

sub all {
  my ($class) = @_;
  return values %known;
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
    ($self->flag_name . "=s") => sub { shift; $self->set_from_flag(@_) }
  } (grep {$_->{has_Flag} || $_->{has_PromptUser}} values %known);
}

sub set_from_flag {
  my ($self, $flagval) = @_;
  $self->{flag_value} = $flagval;
}

sub set_default_from_yaml {
  my ($self, $value) = @_;
  $self->{interactive_default_value} = $value;
}

sub value {
  my ($self) = @_;
  if ($self->{flag_value}) {
    return $self->{flag_value};
  } elsif ($self->{interactive_value}) {
    return $self->{interactive_value};
  } elsif ($self->{has_PromptUser}) {
    my $default_value = $self->{interactive_default_value} || $self->{code_orig}->();
    return ($self->{interactive_value} = GenerateAnswersYaml::_prompt_user(
      $self->human_name, $default_value));
  } else {
    # Flag sub absent from command line
    return $self->{code_orig}->();
  }
}

1;
