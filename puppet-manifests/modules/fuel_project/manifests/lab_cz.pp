# Used for deploy lab-cz.vm.mirantis.net
class fuel_project::lab_cz (
  $external_host = true,
) {
  # Used for network managment
  class { 'common' :
    external_host => $external_host
  }

  include ssh::ldap
  class { 'libvirt' :
    qemu               => false,
    listen_tcp         => false,
    listen_tls         => false,
    unix_sock_rw_perms => '0777',
    unix_sock_group    => 'libvirtd',
  }

  $packages = [
    'syslinux',
    'python-paramiko',
    'python-netaddr',
    'python-xmlbuilder',
    'nfs-kernel-server',
    'ipmitool',
    'vlan',
  ]

  ensure_packages($packages)

  file { '/etc/exports' :
    ensure  => 'present',
    content => "/var/lib/tftpboot *(ro,async,no_subtree_check,no_root_squash,crossmnt)\n",
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    require => Package['nfs-kernel-server'],
    notify  => Service['nfs-export-fuel'],
  }

  service { 'nfs-export-fuel' :
    ensure  => 'running',
    name    => 'nfs-kernel-server',
    enable  => true,
    restart => true,
  }

  file { [
      '/var/lib/tftpboot',
      '/var/lib/tftpboot/pxelinux.cfg',
      '/srv/downloads' ] :
    ensure => 'directory',
    owner  => 'root',
    group  => 'root',
    mode   => '0777',
  }

  file { '/var/lib/tftpboot/pxelinux.0' :
    ensure  => 'present',
    source  => 'file:///usr/lib/syslinux/pxelinux.0',
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    require => [
      File['/var/lib/tftpboot'],
      Package['syslinux'],
    ]
  }

  file { '/var/lib/tftpboot/pxelinux.cfg/default' :
    ensure  => 'present',
    source  => 'puppet:///modules/fuel_project/lab_cz/default',
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    require => File['/var/lib/tftpboot/pxelinux.cfg'],
  }

  file { '/etc/sudoers.d/deploy' :
    ensure => 'present',
    source => 'puppet:///modules/fuel_project/lab_cz/sudo_deploy',
    owner  => 'root',
    group  => 'root',
    mode   => '0440',
  }

  file { '/etc/network/interfaces' :
    ensure => 'present',
    source => 'puppet:///modules/fuel_project/lab_cz/network_interfaces',
    owner  => 'root',
    group  => 'root',
    mode   => '0644',
  }
}
