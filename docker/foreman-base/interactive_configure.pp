# = Class: interactive_configure
#
# Dummy class used as a trick to remember interactive answers to
# configure.pl inside foreman-installer-answers.yaml
#
# === Parameters:
#
# $answers::      Ignored - This is just a placeholder for the
#                 configure.pl script to persist the user-provided
#                 answers
class interactive_configure(
  $answers = {}
) {
}

