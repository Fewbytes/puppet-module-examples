class mysql::server {

  package {"mysql-server": }

  service {"mysql":
    enable => true,
    ensure => running,
    require => Package["mysql-server"],
  }
}
