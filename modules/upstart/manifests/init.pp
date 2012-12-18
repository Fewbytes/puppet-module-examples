class upstart {
    package { "upstart": }
}

define upstart::job(
    $description = '',
    $fork=false,
    $command='',
    $use_script=false
) {
    file { "/etc/init/${name}.conf":
        content => template('upstart/job.conf.erb'),
        ensure  => present,
    }
    service { "${name}":
        ensure  => "running",
        enable  => "true",
        require => File["/etc/init/${name}.conf"],
    }
}
