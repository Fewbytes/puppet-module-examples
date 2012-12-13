class mysql::server {

  package {"mysql-server":
    name => 'MySQL-server',
    ensure => installed
  }

  service {"mysql":
    enable => true,
    ensure => running,
    require => Package["mysql-server"],
  }
}
