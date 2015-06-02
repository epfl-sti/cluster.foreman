class epflsti::private::params() {
  # TODO: this list should be auto-computed from scraping the Foreman database
  # for hosts that have $is_compute_node set. This is a bit tricky to do efficiently
  # and correctly, though.
  $quorum_nodes = ["compute-0-06.cloud.epfl.ch",
                   "compute-0-11.cloud.epfl.ch",
                   "compute-0-12.cloud.epfl.ch"]
  $dns_domain = "cloud.epfl.ch"
}
