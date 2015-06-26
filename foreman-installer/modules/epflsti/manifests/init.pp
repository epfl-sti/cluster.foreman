# = Class: epflsti
#
# Mock class to hold persistent answers in foreman-installer-answers.yaml
# Customizations to foreman-installer that are specific to EPFL STI.
#
# The epflsti directory gets symlinked as
# /usr/share/foreman-installer/modules/epflsti by configure.pl, and
# then foreman-installer loads the manifests/init.pp therein as part
# of its job.
#
# === Parameters:
#
# $configure_answers::      Ignored - This is a placeholder for the
#                           configure.pl script to persist the user-provided
#                           answers that don't have a specific YAML
#                           configuration entry of their own  
class epflsti(
  $configure_answers = {}
) {
}
