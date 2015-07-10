package EPFLSTI::Foreman::Configure;

use strict;
use warnings;

=head1 NAME

EPFLSTI::Foreman::Configure - The engine behind configure.pl

=head1 SYNOPSIS

The following declares the function that computes the value for the
C<tftp_servername> entry in C<foreman_proxy>:

   sub foreman_proxy__tftp_servername : ToYaml  { ... }

The following computes only a default value; the actual value will be
asked interactively from the user.

   sub private_ip_address : PromptUser { ... }

Functions can also have multiple attributes:

  sub foreman_proxy__dhcp_range : ToYaml : PromptUser { ... }

=head1 DESCRIPTION

=cut

use base 'Exporter'; our @EXPORT_OK = qw(debug prompt_user prompt_yn);

use Attribute::Handlers;
use Getopt::Long;
use YAML::Tiny;
use Tie::IxHash;
use FindBin qw($Bin);
use EPFLSTI::Interactive qw(prompt_yn);

# Both of these can be changed with L</parse_argv>.

our $target_file = "$Bin/foreman-installer-answers.yaml";

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
  EPFLSTI::Foreman::Configure::_MagicSub->decorate(@_);
}

=head2 Flag

There's a flag to override (the default value of) this function.

The flag name is derived from the name of the function by folding to
lowercase and replacing underscores with dashes.

=cut

sub UNIVERSAL::Flag : ATTR(CODE) {
  debug(_function_name($_[2]) . "? There's a flag for that!");
  EPFLSTI::Foreman::Configure::_MagicSub->decorate(@_);
}

=head2 PromptUser

=head2 PromptUser (validate => \&my_validation_sub)

Functions in ../configure.pl decorated with this attribute prompt the
user for their return value. The return value of the function body is
used as the default.

C<PromptUser> implies L</Flag>; if the flag is present on the command
line, then the user is I<not> prompted.

If a validating function is specified, that function will be called
with a reference to the user-specified value as the first argument.
The function may modify the user-specified value, or throw an
exception if the user-specified value is unacceptable.

=cut

sub UNIVERSAL::PromptUser : ATTR(CODE) {
  debug(_function_name($_[2]) . " is supposed to prompt the user");
  EPFLSTI::Foreman::Configure::_MagicSub->decorate(@_);
}

sub _function_name {
  my ($sub_ref) = @_;
  # https://stackoverflow.com/questions/7419071/determining-the-subroutine-name-of-a-perl-code-reference
  use B qw(svref_2object);
  return svref_2object($sub_ref)->GV->NAME;
}

=head2 PreConfigure

Functions annotated with this attribute are run first.

=cut

sub UNIVERSAL::PreConfigure : ATTR(CODE) {
  debug(_function_name($_[2]) . " will run at the beginning");
  EPFLSTI::Foreman::Configure::_MagicSub->decorate(@_);
}

=head2 PostConfigure

Functions annotated with this attribute are run (typically for their
side effects) after foreman-installer-answers.yaml is written.

=cut

sub UNIVERSAL::PostConfigure : ATTR(CODE) {
  debug(_function_name($_[2]) . " will run at the end");
  EPFLSTI::Foreman::Configure::_MagicSub->decorate(@_);
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
  if ($ARGV[0] && $ARGV[0] =~ m/-h|help/) {
    my $flags = join("", map {
      my $flagname = $_->flag_name;
      "  --$flagname\n"
    } (grep {$_->is_settable_from_flag}
       EPFLSTI::Foreman::Configure::_MagicSub->all));

    die <<"USAGE";
Tune $target_file prior to (re-)running foreman-installer.

Usage: $0 [flags]

Known flags:

$flags
USAGE
  }
  die "Bad flags" unless GetOptions(
    "target-file=s" => sub { my ($opt, $value) = @_; $target_file = $value },
    EPFLSTI::Foreman::Configure::_MagicSub->getopt_spec);
}

=head2 generate

Perform the update on foreman-installer-answers.yaml,
then run any L<PostConfigure> subs in the order they were seen.

=cut

sub generate {
  parse_argv;
  foreach my $magicsub (EPFLSTI::Foreman::Configure::_MagicSub->all) {
    next unless ($magicsub->has_PreConfigure);
    $magicsub->{code_orig}->();
  }

  if (-f $target_file) {
    warn "$target_file already exists.\n\n";
  }
  my $state = EPFLSTI::Foreman::Configure::_YamlState->load($target_file);
  $state->compute_all;
  do {
    open(OUT, ">", "$target_file.new") &&
      (print OUT $state->dump) &&
      close(OUT)
  } or die "Cannot write to $target_file.new: $!";
  rename("$target_file.new", $target_file) or
    die "Cannot rename $target_file.new to $target_file: $!";
  warn "Configuration updated in $target_file.\n\n";
  foreach my $magicsub (EPFLSTI::Foreman::Configure::_MagicSub->all) {
    next unless ($magicsub->has_PostConfigure);
    $magicsub->{code_orig}->();
  }
}

=head1 EPFLSTI::Foreman::Configure::_YamlState

Models the entire state of the script.

=cut

package EPFLSTI::Foreman::Configure::_YamlState;

sub load {
  my ($class, $filename) = @_;
  die unless defined $filename;
  my $state;
  if (! -f $filename) {
    tie(my %objects, "Tie::IxHash");
    $state = \%objects;
  } else {
    # Not sure how to keep order when loading, oh well
    $state = YAML::Tiny->read($filename)->[0];
  }
  my $self = bless {
    state => $state
  }, $class;
  # Read default values for : PromptUser subs
  foreach my $magicsub (EPFLSTI::Foreman::Configure::_MagicSub->all) {
    next unless ($magicsub->has_PromptUser);
    my @key = $magicsub->yaml_key;
    next unless $self->exists(@key);
    $magicsub->set_default_from_yaml($self->get(@key));
  }
  return $self;
}

sub exists {
  my ($self, @key) = @_;
  my ($struct, $lastkey) = $self->_walk(@key);
  return exists $struct->{$lastkey};
}

sub _walk {
  my ($self, @key) = @_;
  die if ! @key;
  my $struct = $self->{state};
  while(@key > 1) {
    my $key = shift @key;
    if (! exists $struct->{$key}) {
      $struct->{$key} = {};
    }
    $struct = $struct->{$key};
  }
  return ($struct, $key[0]);
}

sub get {
  my ($self, @key) = @_;
  my ($struct, $lastkey) = $self->_walk(@key);
  return $struct->{$lastkey};
}

sub set {
  my $val = pop @_;
  my ($self, @key) = @_;
  my ($struct, $lastkey) = $self->_walk(@key);
  $struct->{$lastkey} = $val;
}


sub update {
  my ($self, $magicsub) = @_;
  $self->set($magicsub->yaml_key, $magicsub->value());
}

sub compute_all {
  my ($self) = @_;
  my @all = EPFLSTI::Foreman::Configure::_MagicSub->all;
  foreach my $magicsub (@all) {
    if ($magicsub->has_ToYaml) {
      $self->update($magicsub);
    }
  }
  foreach my $magicsub (@all) {
    if ($magicsub->has_PromptUser && ! $magicsub->has_ToYaml &&
          $magicsub->answered) {
      $self->update($magicsub);
    }
  }
}

sub dump {
  my ($self) = @_;
  if ($ENV{DEBUG} && $ENV{DEBUG} >= 9) {
    require Data::Dumper;
    EPFLSTI::Foreman::Configure::debug(Data::Dumper::Dumper($self->{state}));
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

=head1 EPFLSTI::Foreman::Configure::_MagicSub

Models a sub decorated with L</ToYaml>, L</PromptUser> and/or
L</Flag>.

=cut

package EPFLSTI::Foreman::Configure::_MagicSub;
use EPFLSTI::Interactive qw(prompt_user);

use vars qw(%known);
tie(%known, "Tie::IxHash");

sub _find {
  my ($class, $coderef) = @_;
  my $name = EPFLSTI::Foreman::Configure::_function_name($coderef);
  return ($known{$name} ||=
            bless { name => $name, code_orig => $coderef }, $class);
}

sub decorate {
  my ($class, undef, $glob, $coderef, $attr, $value) = @_;
  my $self = $class->_find($coderef);
  $self->{"decoration_$attr"} = $value;
  unless ($attr eq "ToYaml") {
    # Set one and the same wrapper for all annotations that require one.
    # This guarantees that said annotations are commutative.
    EPFLSTI::Foreman::Configure::debug(
      $self->{name} . " is being wrapped");
    no warnings "redefine";
    *$glob = sub { $self->value() };
  }
}

sub has_PromptUser { exists shift->{decoration_PromptUser} }
sub has_Flag { exists shift->{decoration_Flag} }
sub has_ToYaml { exists shift->{decoration_ToYaml} }
sub has_PreConfigure { exists shift->{decoration_PreConfigure} }
sub has_PostConfigure { exists shift->{decoration_PostConfigure} }

sub param_PromptUser {
  my ($self, $key) = @_;
  return unless (ref($self->{decoration_PromptUser}) eq "ARRAY");
  $self->{params_PromptUser} ||= {@{$self->{decoration_PromptUser}}};
  return $self->{params_PromptUser}->{$key};
}

sub all {
  my ($class) = @_;
  return values %known;
}

sub yaml_key {
  my ($self) = @_;
  if ($self->has_ToYaml) {
    if (ref($self->{decoration_ToYaml}) eq "ARRAY") {
      return @{$self->{decoration_ToYaml}};
    } else {
      my $key = lc($self->{name});
      return split m/__/, $key;
    }
  } elsif ($self->has_PromptUser) {
    # We can't pick our own top-level name, lest foreman-installer believe
    # that it references a module. Hide our data under a dud foreman-installer
    # module (see docker/foreman-base/interactive_configure.pp).
    return ("interactive_configure", "answers", $self->{name});
  } else {
    die "$self->{name} is not persistent";
  }
}

sub flag_name {
  my ($self) = @_;
  my $flag = lc($self->{name});
  $flag =~ s/_+/-/g;
  return $flag;
}

sub human_name {
  my ($self) = @_;
  my $flag = ucfirst($self->{name});
  $flag =~ s/_+/ /g;
  return $flag;
}

sub getopt_spec {
  my ($class) = @_;
  return map {
    my $self = $_;
    ($self->flag_name . "=s") => sub { shift; $self->set_from_flag(@_) }
  } (grep {$_->is_settable_from_flag} $class->all);
}

sub set_from_flag {
  my ($self, $flagval) = @_;
  $self->{flag_value} = $flagval;
}

sub is_settable_from_flag {
  my ($self) = @_;
  return ($self->has_Flag || $self->has_PromptUser);
}

sub set_default_from_yaml {
  my ($self, $value) = @_;
  $self->{interactive_default_value} = $value;
}

sub value {
  my ($self) = @_;
  if ($self->{flag_value}) {
    return $self->{flag_value};
  } elsif (exists $self->{interactive_value}) {
    return $self->{interactive_value};
  } elsif ($self->has_PromptUser) {
    my $default_value = $self->{interactive_default_value} || $self->{code_orig}->();
    my $answer = prompt_user(
      $self->human_name, $default_value);
    if (my $validator = $self->param_PromptUser("validate")) {
      $validator->(\$answer);
    }
    $self->{interactive_value} = $answer;
  } else {
    # Flag sub absent from command line
    return $self->{code_orig}->();
  }
}

sub answered { exists shift->{interactive_value} }

1;
