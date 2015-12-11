# Class: fuel_project::gerrit
#
class fuel_project::gerrit (
  $gerrit_auth_type = undef,
  $replica_points   = undef,
  $replication_mode = '',

) {

  $gerrit = hiera_hash('gerrit')
  class { '::gerrit' :
    canonicalweburl                     => $gerrit['service_url'],
    contactstore                        => $gerrit['contactstore'],
    container_heaplimit                 => floor($::memorysize_mb/2*1024*1024),
    email_private_key                   => $gerrit['email_private_key'],
    gerrit_auth_type                    => $gerrit_auth_type,
    gerrit_start_timeout                => $gerrit['start_timeout'],
    gitweb                              => true,
    mysql_database                      => $gerrit['mysql_database'],
    mysql_host                          => $gerrit['mysql_host'],
    mysql_password                      => $gerrit['mysql_password'],
    mysql_user                          => $gerrit['mysql_user'],
    service_fqdn                        => $gerrit['service_fqdn'],
    ssh_dsa_key_contents                => $gerrit['ssh_dsa_key_contents'],
    ssh_dsa_pubkey_contents             => $gerrit['ssh_dsa_pubkey_contents'],
    ssh_project_rsa_key_contents        => $gerrit['project_ssh_rsa_key_contents'],
    ssh_project_rsa_pubkey_contents     => $gerrit['project_ssh_rsa_pubkey_contents'],
    ssh_replication_rsa_key_contents    => $gerrit['replication_ssh_rsa_key_contents'],
    ssh_replication_rsa_pubkey_contents => $gerrit['replication_ssh_rsa_pubkey_contents'],
    ssh_rsa_key_contents                => $gerrit['ssh_rsa_key_contents'],
    ssh_rsa_pubkey_contents             => $gerrit['ssh_rsa_pubkey_contents'],
    ssl_cert_file                       => $gerrit['ssl_cert_file'],
    ssl_cert_file_contents              => $gerrit['ssl_cert_file_contents'],
    ssl_chain_file                      => $gerrit['ssl_chain_file'],
    ssl_chain_file_contents             => $gerrit['ssl_chain_file_contents'],
    ssl_key_file                        => $gerrit['ssl_key_file'],
    ssl_key_file_contents               => $gerrit['ssl_key_file_contents'],
  }

  class { '::gerrit::mysql' :
    database_name     => $gerrit['mysql_database'],
    database_user     => $gerrit['mysql_user'],
    database_password => $gerrit['mysql_password'],
  }

  class { '::gerrit::hideci' :}

  if ($replication_mode == 'master' and $replica_points) {
    create_resources(
      ::fuel_project::gerrit::replication,
      $replica_points,
    )
  }

  if ($replication_mode == 'slave') {
    class { '::fuel_project::gerrit::replication_slave' :}
  }

}
