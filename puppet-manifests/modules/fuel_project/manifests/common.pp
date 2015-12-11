# Class: fuel_project::common
#
class fuel_project::common (
  $bind_policy        = '',
  $external_host      = false,
  $facts              = {
    'location' => $::location,
    'role'     => $::role,
  },
  $kernel_package     = undef,
  $ldap               = false,
  $ldap_base          = '',
  $ldap_ignore_users  = '',
  $ldap_uri           = '',
  $logrotate_rules    = hiera_hash('logrotate::rules', {}),
  $pam_filter         = '',
  $pam_password       = '',
  $root_password_hash = 'r00tme',
  $root_shell         = '/bin/bash',
  $tls_cacertdir      = '',
) {
  class { '::atop' :}
  class { '::ntp' :}
  class { '::puppet::agent' :}
  class { '::ssh::authorized_keys' :}
  class { '::ssh::sshd' :
    apply_firewall_rules => $external_host,
  }
  # TODO: remove ::system module
  # ... by spliting it's functions to separate modules
  # or reusing publically available ones
  class { '::system' :}
  class { '::zabbix::agent' :
    apply_firewall_rules => $external_host,
  }

  ::puppet::facter { 'facts' :
    facts => $facts,
  }

  ensure_packages([
    'apparmor',
    'facter-facts',
    'screen',
    'tmux',
  ])

  # install the exact version of kernel package
  # please note, that reboot must be done manually
  if($kernel_package) {
    ensure_packages($kernel_package)
  }

  if($ldap) {
    class { '::ssh::ldap' :}

    file { '/usr/local/bin/ldap2sshkeys.sh' :
      ensure  => 'present',
      mode    => '0700',
      owner   => 'root',
      group   => 'root',
      content => template('fuel_project/common/ldap2sshkeys.sh.erb'),
    }

    exec { 'sync-ssh-keys' :
      command   => '/usr/local/bin/ldap2sshkeys.sh',
      logoutput => on_failure,
      require   => File['/usr/local/bin/ldap2sshkeys.sh'],
    }

    cron { 'ldap2sshkeys' :
      command => "/usr/local/bin/ldap2sshkeys.sh ${::hostname} 2>&1 | logger -t ldap2sshkeys",
      user    => root,
      hour    => '*',
      minute  => fqdn_rand(59),
      require => File['/usr/local/bin/ldap2sshkeys.sh'],
    }
  }

  case $::osfamily {
    'Debian': {
      class { '::apt' :}
    }
    'RedHat': {
      class { '::yum' :}
    }
    default: { }
  }

  # Logrotate items
  create_resources('::logrotate::rule', $logrotate_rules)

  zabbix::item { 'software-zabbix-check' :
    template => 'fuel_project/common/zabbix/software.conf.erb',
  }

  # Zabbix hardware item
  ensure_packages(['smartmontools'])

  ::zabbix::item { 'hardware-zabbix-check' :
    content => 'puppet:///modules/fuel_project/common/zabbix/hardware.conf',
    require => Package['smartmontools'],
  }
  # /Zabbix hardware item

  # Zabbix SSL item
  file { '/usr/local/bin/zabbix_check_certificate.sh' :
    ensure => 'present',
    mode   => '0755',
    source => 'puppet:///modules/fuel_project/zabbix/zabbix_check_certificate.sh',
  }
  ::zabbix::item { 'ssl-certificate-check' :
    content => 'puppet:///modules/fuel_project/common/zabbix/ssl-certificate-check.conf',
    require => File['/usr/local/bin/zabbix_check_certificate.sh'],
  }
  # /Zabbix SSL item

  mount { '/' :
    ensure  => 'present',
    options => 'defaults,errors=remount-ro,noatime,nodiratime,barrier=0',
  }

  file { '/etc/hostname' :
    ensure  => 'present',
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => "${::fqdn}\n",
    notify  => Exec['/bin/hostname -F /etc/hostname'],
  }

  file { '/etc/hosts' :
    ensure  => 'present',
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template('fuel_project/common/hosts.erb'),
  }

  exec { '/bin/hostname -F /etc/hostname' :
    subscribe   => File['/etc/hostname'],
    refreshonly => true,
    require     => File['/etc/hostname'],
  }
}
