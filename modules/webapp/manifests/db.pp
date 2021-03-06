# Class: webapp::db
#
# This is a thin wrapper around the mysql::db custom resource, for deploying a webapp's database.
#

class webapp::db (
  $user,
  $password,
  $host = '%',
  $db = 'webapp'
) {
  mysql::db { $db:
  }
  mysql::grant { "grant remote":
    user => $user,
    password => $password,
    db => 'webapp',
    host => '%',
  }
  mysql::grant { "grant local":
    user => $user,
    password => $password,
    db => 'webapp',
    host => 'localhost',
  }
  class { 'mysql::config':
    bind_address => '0.0.0.0',
    require => Class['mysql::server'],
  }

  #register attributes in cloudify
  cloudify_attribute { 'user':
    value => $user,
    type => 'service',
    ensure  => present,
  }
  cloudify_attribute { 'password':
    value => $password,
    type => 'service',
    ensure  => present,
  }
  cloudify_attribute { 'db_name':
    value => $db,
    type => 'service',
    ensure  => present,
  }
  cloudify_attribute { 'ip': #note: this gives the internal ip. Perhaps it'd be better to just pull it from the context?
    value => $ipaddress,
    type => 'service',
    ensure  => present,
  }
}
