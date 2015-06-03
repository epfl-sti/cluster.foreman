class epflsti::private::params() {
  # This is the default behavior, but can be overridden
  $is_frontend_node = $epflsti::is_puppetmaster

  # TODO: this list should be auto-computed from scraping the Foreman database
  # for hosts that have $is_compute_node set. This is a bit tricky to do efficiently
  # and correctly, though.
  $quorum_nodes = ["compute-0-06.cloud.epfl.ch",
                   "compute-0-11.cloud.epfl.ch",
                   "compute-0-12.cloud.epfl.ch"]
  # TODO: every physical location should use its own DNS server and ad-hoc domain
  # (e.g. .bm.cloud.epfl.ch, .nemesis.cloud.epfl.ch)
  $dns_domain = "cloud.epfl.ch"
}
