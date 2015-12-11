# Class: fuel_project::nailgun_demo
#
class fuel_project::nailgun_demo (
  $apply_firewall_rules = false,
  $lock_file            = '',
  $nginx_access_log     = '/var/log/nginx/access.log',
  $nginx_error_log      = '/var/log/nginx/error.log',
  $nginx_log_format     = 'proxy',
  $server_name          = '',
) {

  if (!defined(Class['fuel_project::common'])) {
    class { 'fuel_project::common':
      external_host => $apply_firewall_rules,
    }
  }

  if (!defined(Class['fuel_project::nginx'])) {
    class { 'fuel_project::nginx': }
  }

  if (!defined(Class['postgresql::server'])) {
    class { 'postgresql::server': }
  }

  # required packages
  # http://docs.mirantis.com/fuel-dev/develop/nailgun/development/env.html
  $packages = [
    'git',
    'npm',
    'nodejs-legacy',
    'postgresql-server-dev-all',
  ]

  $npm_packages = [
    'grunt-cli',
    'gulp',
    'inflight',
  ]

  package { $packages:
    ensure => 'present',
  }

  ensure_packages($npm_packages, {
    provider => npm,
    require  => Package['npm'],
  })

  # create main user
  user { 'nailgun':
    ensure     => 'present',
    home       => '/home/nailgun',
    managehome => true,
  }

  # create log directory
  file { '/var/log/nailgun':
    ensure  => 'directory',
    owner   => 'nailgun',
    require => User['nailgun'],
  }

  file { '/var/log/remote':
    ensure  => 'directory',
    owner   => 'nailgun',
    require => User['nailgun'],
  }

  # create main directories
  file { '/usr/share/fuel-web':
    ensure  => 'directory',
    owner   => 'nailgun',
    require => User['nailgun'],
  }

  # clone fuel-web
  vcsrepo { '/usr/share/fuel-web':
    ensure   => 'present',
    provider => 'git',
    source   => 'https://github.com/stackforge/fuel-web',
    user     => 'nailgun',
    require  => [User['nailgun'],
                File['/usr/share/fuel-web'],
                Package['git'] ],
  }

  # prepare database
  postgresql::server::db { 'nailgun' :
    user     => 'nailgun',
    password => postgresql_password('nailgun', 'nailgun'),
  }

  # prepare environment
  venv::venv { 'venv-nailgun' :
    path         => '/home/nailgun/python',
    requirements => '/usr/share/fuel-web/nailgun/requirements.txt',
    options      => '',
    user         => 'nailgun',
    require      => [
      Vcsrepo['/usr/share/fuel-web'],
      Package[$packages],
    ]
  }

  venv::exec { 'venv-syncdb' :
    command => './manage.py syncdb',
    cwd     => '/usr/share/fuel-web/nailgun',
    venv    => '/home/nailgun/python',
    user    => 'nailgun',
    require => [Venv::Venv['venv-nailgun'],
                Postgresql::Server::Db['nailgun'],],
    onlyif  => "test ! -f ${lock_file}",
  }

  venv::exec { 'venv-loaddefault' :
    command => './manage.py loaddefault',
    cwd     => '/usr/share/fuel-web/nailgun',
    venv    => '/home/nailgun/python',
    user    => 'nailgun',
    require => Venv::Exec['venv-syncdb'],
    onlyif  => "test ! -f  ${lock_file}",
  }

  venv::exec { 'venv-loaddata' :
    command => './manage.py loaddata nailgun/fixtures/sample_environment.json',
    cwd     => '/usr/share/fuel-web/nailgun',
    venv    => '/home/nailgun/python',
    user    => 'nailgun',
    require => Venv::Exec['venv-loaddefault'],
    onlyif  => "test ! -f ${lock_file}",
  }

  exec { 'venv-npm' :
    command => 'npm install',
    cwd     => '/usr/share/fuel-web/nailgun',
    user    => 'nailgun',
    require => [
      Venv::Exec['venv-loaddata'],
      Package[$npm_packages],
    ],
    onlyif  => "test ! -f ${lock_file}",
  }

  exec { 'venv-gulp' :
    command     => '/usr/local/bin/gulp bower',
    cwd         => '/usr/share/fuel-web/nailgun',
    environment => 'HOME=/home/nailgun',
    user        => 'nailgun',
    require     => Exec['venv-npm'],
    onlyif      => "test ! -f ${lock_file}",
  }

  file_line { 'fake_mode':
    path    => '/usr/share/fuel-web/nailgun/nailgun/settings.yaml',
    line    => 'FAKE_TASKS: "1"',
    require => Vcsrepo['/usr/share/fuel-web'],
  }

  ::nginx::resource::vhost { 'demo-redirect' :
    ensure              => 'present',
    listen_port         => 80,
    server_name         => [$server_name],
    www_root            => '/var/www',
    access_log          => $nginx_access_log,
    error_log           => $nginx_error_log,
    format_log          => $nginx_log_format,
    location_cfg_append => {
      rewrite => '^ http://$server_name:8000$request_uri permanent',
    },
  }

  nginx::resource::vhost { 'demo' :
    ensure              => 'present',
    listen_port         => 8000,
    server_name         => [$server_name],
    access_log          => $nginx_access_log,
    error_log           => $nginx_error_log,
    format_log          => $nginx_log_format,
    uwsgi               => '127.0.0.1:7933',
    location_cfg_append => {
      uwsgi_connect_timeout => '3m',
      uwsgi_read_timeout    => '3m',
      uwsgi_send_timeout    => '3m',
    }
  }

  nginx::resource::location { 'demo-static' :
    ensure   => 'present',
    vhost    => 'demo',
    location => '/static/',
    www_root => '/usr/share/fuel-web/nailgun',
  }

  uwsgi::application { 'fuel-web' :
    plugins        => 'python',
    uid            => 'nailgun',
    gid            => 'nailgun',
    socket         => '127.0.0.1:7933',
    chdir          => '/usr/share/fuel-web/nailgun',
    home           => '/home/nailgun/python',
    module         => 'nailgun.wsgi:application',
    env            => 'DJANGO_SETTINGS_MODULE=nailgun.settings',
    workers        => '8',
    enable_threads => true,
    require        => [File_line['fake_mode'],
                Exec['venv-gulp'],
                User['nailgun'],],
  }

  if $apply_firewall_rules {
    include firewall_defaults::pre
    firewall { '1000 Allow demo 80, 8000 connection' :
      ensure  => present,
      dport   => [80, 8000],
      proto   => 'tcp',
      action  => 'accept',
      require => Class['firewall_defaults::pre'],
    }
  }

}
