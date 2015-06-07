class epflsti::private::bugware() {
  # https://serverfault.com/questions/111766/adding-a-yum-repo-to-puppet-before-doing-anything-else
  Yumrepo <| |> -> Package <| provider != 'rpm' |>
}
