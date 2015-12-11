# Class: fuel_project::mongodb
#

class fuel_project::mongodb (
  $user           = 'ceilometer',
  $admin_username = 'admin',
  $password       = 'ceilometer',
  $admin_password = 'admin',
  $admin_database = 'admin',
)
{
  mongodb::db { 'ceilometer':
    user           => $user,
    password       => $password,
    roles          => [ 'readWrite', 'dbAdmin' ],
    admin_username => $admin_username,
    admin_password => $admin_password,
    admin_database => $admin_database,
  } ->

  mongodb::db { 'admin':
    user           => $admin_username,
    password       => $admin_password,
    roles          => [
      'userAdmin',
      'readWrite',
      'dbAdmin',
      'dbAdminAnyDatabase',
      'readAnyDatabase',
      'readWriteAnyDatabase',
      'userAdminAnyDatabase',
      'clusterAdmin',
      'clusterManager',
      'clusterMonitor',
      'hostManager',
      'root',
      'restore',
    ],
    admin_username => $admin_username,
    admin_password => $admin_password,
    admin_database => $admin_database,
  }

}
