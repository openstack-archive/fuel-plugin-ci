# Class: ssh::banner
#
class ssh::banner {
  file { '/etc/banner' :
    owner   => 'root',
    group   => 'root',
    mode    => '0400',
    content => template('ssh/banners/mirantis.net_ldap.erb')
  }
}
