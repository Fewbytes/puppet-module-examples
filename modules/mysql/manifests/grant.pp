define mysql::grant(
    $password,
    $db,
    $host = '%',
    $grant = 'all'
) {
	include mysql::server

	exec {"mysql-grant-${db}-${name}-${host}":
	  unless => "/usr/bin/mysql -uroot -sse 'select count(1) from mysql.user where user=\"${name}\" and host=\"${host}\" and password=PASSWORD(\"${password}\")' | /bin/grep 1",
	  command => "/usr/bin/mysql -uroot -e 'grant ${grant} on ${db}.* to \"${name}\"@\"${host}\" identified by \"$password\";'",
	  require => [Service["mysql"], Mysql::Db["${db}"]]
	}
}
