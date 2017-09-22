package EPFLSTI::Interactive;

use base qw(Exporter); our @EXPORT = our @EXPORT_OK = qw(prompt_user prompt_yn);

sub prompt_user {
  my ($question, $default) = @_;
  if (defined($default)) {
    chomp($question);
    print "$question [$default]:\n";
  } else {
    print "$question";
  }
  my $answer = <STDIN>;
  chomp($answer);
  if ($answer eq "") {
    return $default;
  } elsif ($answer eq ".") {
    return "";  # OpenSSL-style
  } else {
    return $answer;
  }
}

sub prompt_yn {
  my ($question, $default_bool) = @_;
  my $prompt = $default_bool ? "Yn" : "yN";
  print "$question [$prompt]:\n";
  my $answer = <STDIN>;
  chomp($answer);
  if ($answer eq "") {
    return $default_bool;
  } elsif (lc($answer) =~ m/^y/) {
    return 1;
  } else {
    return undef;
  }
}

