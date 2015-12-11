# class fuel_project::racktables
class fuel_project::racktables (
  $firewall_enable = false,
) {
  class { '::fuel_project::common' :
    external_host => $firewall_enable,
  }
  class { '::fuel_project::nginx' : }
  class { '::racktables' : }

  if ($firewall_enable) {
    include firewall_defaults::pre
    firewall { '1000 - allow http/https connections to racktables' :
      dport   => [80, 443],
      action  => 'accept',
      require => Class['firewall_defaults::pre'],
    }
  }
}
