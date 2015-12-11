# class racktables
class racktables (
  $admin_password        = 'racktables',
  $db_host               = 'localhost',
  $db_name               = 'racktables',
  $db_password           = 'racktables',
  $db_username           = 'racktables',
  $ldap_options          = undef,
  $nginx_access_log      = '/var/log/nginx/access.log',
  $nginx_error_log       = '/var/log/nginx/error.log',
  $nginx_log_format      = undef,
  $require_local_account = true,
  $service_fqdn          = 'racktables.test.local',
  $ssl_cert_content      = '',
  $ssl_cert_filename     = '/etc/ssl/racktables.crt',
  $ssl_key_content       = '',
  $ssl_key_filename      = '/etc/ssl/racktables.key',
  $user_auth_src         = 'database',
) {
  $php_modules = [ 'mysql', 'ldap', 'gd', 'cli' ]
  $www_root = '/usr/share/racktables/wwwroot'

  class { '::php::fpm::daemon' : }
  ::php::module { $php_modules : }

  ::nginx::resource::vhost { 'racktables-server' :
    ensure               => 'present',
    listen_port          => 80,
    ssl                  => false,
    server_name          => [$service_fqdn, $::fqdn],
    access_log           => $nginx_access_log,
    error_log            => $nginx_error_log,
    format_log           => $nginx_log_format,
    use_default_location => false,
    require              => Package['racktables'],
  }

  if ($ssl_cert_content and $ssl_key_content) {
    $ssl = true
    file { $ssl_cert_filename :
      ensure  => 'present',
      mode    => '0600',
      owner   => 'root',
      content => $ssl_cert_content,
    }
    file { $ssl_key_filename :
      ensure  => 'present',
      mode    => '0600',
      owner   => 'root',
      content => $ssl_key_content,
    }
    Nginx::Resource::Vhost <| title == 'racktables-server' |>{
      ssl         => true,
      ssl_cert    => $ssl_cert_filename,
      ssl_key     => $ssl_key_filename,
      listen_port => 443,
      ssl_port    => 443,
    }
    ::nginx::resource::vhost { 'racktables-redirect' :
      ensure              => 'present',
      server_name         => [$service_fqdn],
      listen_port         => 80,
      www_root            => $www_root,
      access_log          => $nginx_access_log,
      error_log           => $nginx_error_log,
      format_log          => $nginx_log_format,
      location_cfg_append => {
        return => "301 https://${service_fqdn}\$request_uri",
      },
      require             => Package['racktables'],
    }
  }

  user { 'racktables' :
    ensure => 'present',
    shell  => '/usr/sbin/nologin',
    home   => '/var/www',
  }
  package { 'racktables' :
    ensure => 'present',
  }

  class { '::mysql::server' : }
  class { '::mysql::server::account_security' :}
  ::mysql::db { $db_name :
    user     => $db_username,
    password => $db_password,
    host     => $db_host,
    grant    => ['all'],
    charset  => 'utf8',
    require  => [
      Class['::mysql::server'],
      Class['::mysql::server::account_security'],
    ],
  }

  ::nginx::resource::location { 'racktables-server-static' :
    vhost    => 'racktables-server',
    location => '/',
    www_root => $www_root,
    ssl      => $ssl,
    ssl_only => $ssl,
  }

  ::nginx::resource::location { 'racktables-server-php' :
    vhost    => 'racktables-server',
    location => '~ \.php$',
    fastcgi  => '127.0.0.1:9001',
    www_root => $www_root,
    ssl      => $ssl,
    ssl_only => $ssl,
  }

  ::php::fpm::conf { 'www':
    listen    => '127.0.0.1:9001',
    user      => 'racktables',
    php_value => {
      post_max_size      => 16M,
      max_execution_time => 300,
      max_input_time     => 300,
      'date.timezone'    => UTC,
      'cgi.fix_pathinfo' => 1,
    },
    require   => [
      Class['::nginx'],
      User['racktables'],
    ],
  }

  file { '/usr/share/racktables/wwwroot/inc/secret.php' :
    ensure  => 'present',
    owner   => 'racktables',
    group   => 'racktables',
    mode    => '0400',
    content => template('racktables/secret.php.erb'),
    require => Package['racktables'],
    notify  => Exec['php /usr/share/racktables/initdb.php'],
  }

  file { '/usr/share/racktables/initdb.php' :
    ensure  => 'present',
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template('racktables/initdb.php.erb'),
    require => Package['racktables'],
  }

  exec { 'php /usr/share/racktables/initdb.php' :
    command     => 'php /usr/share/racktables/initdb.php',
    cwd         => '/usr/share/racktables/',
    require     => [
      Php::Module[$php_modules],
      Package['racktables'],
      File['/usr/share/racktables/initdb.php'],
      File['/usr/share/racktables/wwwroot/inc/secret.php']
    ],
    refreshonly => true,
  }
}
