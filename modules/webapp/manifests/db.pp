# Class: webapp::db
#
# This is a thin wrapper around the mysql::db custom resource, for deploying a webapp's database.
#

class webapp::db (
  $user,
  $password,
  $host = '%'
) {
  mysql::db { $name:
    user => $user,
    password => $password,
    host => $host,
    grant => ["all"]
  }
}
