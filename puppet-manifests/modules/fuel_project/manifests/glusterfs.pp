# Class: fuel_project::glusterfs
#
# Parameters:
#  $create_pool:
#    if false, then it's just install glusterfs server and client
#  $gfs_pool:
#    list of nodes with glusterfs server installed, will be used for pool
#  $gfs_volume_name:
#    name of datapoint (shared point), will be used by clients for mounting,
#    example: mount -t glusterfs $gfs_pool[0]:/$gfs_volume_name /mnt/local
#  $gfs_brick_point:
#    mount points which are going to be used to building bricks
#
#  The above parameters in terms of glusterfs:
#  1. gluster peer probe $gfs_pool[0]
#     gluster peer probe $gfs_pool[1]
#  2. mkdir -p $gfs_brick_point
#     gluster volume create $gfs_volume_name replica 2 transport tcp \
#          $gfs_pool[0]:$gfs_brick_point $gfs_pool[1]:$gfs_brick_point force
#
# All gluster customization:
# http://docs.openstack.org/admin-guide-cloud/content/glusterfs_backend.html
#
class fuel_project::glusterfs (
  $apply_firewall_rules   = false,
  $create_pool            = false,
  $firewall_allow_sources = {},
  $gfs_brick_point        = '/mnt/brick',
  $gfs_pool               = [ 'slave-13.test.local','slave-14.test.local' ],
  $gfs_volume_name        = 'data',
  $owner_gid              = 165,
  $owner_uid              = 165,

){
  class { '::fuel_project::common' :
    external_host => $apply_firewall_rules,
  }

  if !defined(Class[::zabbix::agent]) {
    class { '::zabbix::agent' :
      apply_firewall_rules => $apply_firewall_rules,
    }
  }

  class { '::glusterfs': }

  # permissions will be managed by glsuterfs itself
  file { $gfs_brick_point:
    ensure => directory,
    mode   => '0775',
  }

  if $create_pool {
    glusterfs_pool { $gfs_pool: }

    glusterfs_vol { $gfs_volume_name :
      replica => 2,
      brick   => [ "${gfs_pool[0]}:${gfs_brick_point}", "${gfs_pool[1]}:${gfs_brick_point}"],
      force   => true,
      require => [
        File[$gfs_brick_point],
        Glusterfs_pool[$gfs_pool],
      ],
    }

    exec { "set_volume_uid_${gfs_volume_name}":
      command => "gluster volume set ${gfs_volume_name} storage.owner-uid ${owner_uid}",
      user    => 'root',
      unless  => "gluster volume info| fgrep 'storage.owner-uid: ${owner_uid}'",
      require => Glusterfs_vol[$gfs_volume_name],
    }

    exec { "set_volume_gid_${gfs_volume_name}":
      command => "gluster volume set ${gfs_volume_name} storage.owner-gid ${owner_gid}",
      user    => 'root',
      unless  => "gluster volume info| fgrep 'storage.owner-gid: ${owner_gid}'",
      require => Glusterfs_vol[$gfs_volume_name],
    }

    exec { "set_volume_param_${gfs_volume_name}":
      command => "gluster volume set ${gfs_volume_name} server.allow-insecure on",
      user    => 'root',
      unless  => 'gluster volume info| fgrep "server.allow-insecure: on"',
      notify  => Exec["restart_volume_${gfs_volume_name}"],
      require => Glusterfs_vol[$gfs_volume_name],
    }

    exec { "restart_volume_${gfs_volume_name}":
      command     => "echo y | gluster volume stop ${gfs_volume_name}; gluster volume start ${gfs_volume_name}",
      user        => 'root',
      refreshonly => true,
    }

  }

  file { '/etc/glusterfs/glusterd.vol' :
    ensure  => 'present',
    owner   => 'root',
    group   => 'root',
    content => template('fuel_project/glusterfs/glusterd.vol.erb'),
    require => Class['glusterfs::package'],
    notify  => Class['glusterfs::service'],
  }

  # put monitoring scripts
  file { '/usr/local/bin' :
    ensure  => directory,
    recurse => remote,
    owner   => 'root',
    group   => 'root',
    mode    => '0754',
    source  => 'puppet:///modules/fuel_project/glusterfs/zabbix/glubix',
  }

  # update sudoerc for zabbix user with monitoring scripts
  file { '/etc/sudoers.d/zabbix_glusterfs' :
    ensure  => 'present',
    owner   => 'root',
    group   => 'root',
    mode    => '0440',
    content => template('fuel_project/glusterfs/sudoers_zabbix_glusterfs.erb')
  }

  zabbix::item { 'glusterfs-zabbix-check' :
    content => 'puppet:///modules/fuel_project/glusterfs/zabbix/userparams-glubix.conf',
    notify  => Service[$::zabbix::params::agent_service],
  }

  if $apply_firewall_rules {
    include firewall_defaults::pre
    # 111   - RPC incomming
    # 24007 - Gluster Daemon
    # 24008 - Management
    # 49152 - (GlusterFS versions 3.4 and later) - Each brick for every volume on your host requires it's own port.
    #         For every new brick, one new port will be used.
    # 2049, 38465-38469 - this is required by the Gluster NFS service.
    create_resources(firewall, $firewall_allow_sources, {
      ensure  => present,
      dport    => [111, 24007, 24008, 49152, 2049, 38465, 38466, 38467, 38468, 38469],
      proto   => 'tcp',
      action  => 'accept',
      require => Class['firewall_defaults::pre'],
    })
  }

}
