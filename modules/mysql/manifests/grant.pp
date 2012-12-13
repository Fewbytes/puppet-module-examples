define mysql::grant(
    $user,
    $password,
    $db,
    $host = '%',
    $grant = 'all'
) {
	include mysql::server

	exec {"mysql-grant-${name}":
	  unless => "/usr/bin/mysql -uroot -sse 'select count(1) from mysql.user where user=\"${user}\" and host=\"${host}\" and password=PASSWORD(\"${password}\")' | /bin/grep 1",
	  command => "/usr/bin/mysql -uroot -e 'grant ${grant} on ${db}.* to \"${user}\"@\"${host}\" identified by \"$password\";'",
	  require => [Service["mysql"], Mysql::Db["${db}"]]
	}
}
