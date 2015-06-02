# Class: epflsti::private::ipmi
#
# Install and configure ipmi and its integration with Foreman
class epflsti::private::ipmi() {
  class { "::ipmi": }
}
