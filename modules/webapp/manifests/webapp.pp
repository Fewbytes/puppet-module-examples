$WEBAPP_REPO="https://github.com/redmine/redmine.git" #TODO: set from cloudify
$WEBAPP_TAG="1.4.5"
$WEBAPP_PATH="/opt/webapps/rails"

package {["rubygems", "ruby-dev", "libxml2-dev", "libxslt-dev", "libsqlite3-dev", "libmysqlclient-dev"]: }
package {"nodejs":} #used for its js runtime engine

exec {'fix gem dates':
    command => "sed -i 's/ 00:00:00.000000000Z//g' /var/lib/gems/1.8/specifications/*",
    path    => "/usr/bin/:/usr/local/bin/:/bin/",
    require => Package['rubygems'],
}

package { ["rails", "unicorn", "execjs"]:
    ensure => present,
    provider => gem,
}

class {'apache': }
apache::module { 'proxy_http': }

file { '/opt/webapps':
    ensure => "directory",
}

exec {'fetch webapp repo':
    command => "git clone $WEBAPP_REPO $WEBAPP_PATH",
    path    => "/usr/bin/:/usr/local/bin/:/bin/",
    creates => "$WEBAPP_PATH",
    require => File['/opt/webapps'],
}

exec {'fetch webapp tag':
    command => "git checkout $WEBAPP_TAG",
    path    => "/usr/bin/:/usr/local/bin/:/bin/",
    cwd     => "$WEBAPP_PATH",
    require => Exec['fetch webapp repo'],
}

exec { "add mysql gems":
    command => "echo \"gem 'mysql2'\" >>$WEBAPP_PATH/Gemfile",
    unless  => "grep 'mysql2' $WEBAPP_PATH/Gemfile",
    path    => "/usr/bin/:/usr/local/bin/:/bin/",
    require => Exec['fetch webapp tag']
}

exec {'bundle install --without development test rmagick postgresql':
    cwd     => "$WEBAPP_PATH",
    path    => "/usr/bin/:/usr/local/bin/:/bin/",
    require => Exec['fix gem dates', "add mysql gems"]
}

#a fix for: A key is required to write a cookie containing the session data. Use config.action_controller.session = { :key => "_myapp_session", :secret => "some secret phrase" } in config/environment.rb
#exec {'generate secret':
#    command => "printf 'config.action_controller.session = { :key => \"_myapp_session\", :secret => \"%s\" }\n' `bundle exec rake secret` >$WEBAPP_PATH/config/initializers/the_secret_token.rb",
#    cwd     => "$WEBAPP_PATH",
#    path    => "/usr/bin/:/usr/local/bin/:/bin/",
#    require => Exec['bundle install'],
#    creates => "$WEBAPP_PATH/config/initializers/the_secret_token.rb",
#}

exec {'generate secret':
    command => "rake generate_session_store",
    cwd     => "$WEBAPP_PATH",
    path    => "/usr/bin/:/usr/local/bin/:/bin/",
    require => Exec['bundle install'],
}

#use the mysql service for the production db
$db_user = get_cloudify_attribute('user', 'service', 'hello-puppet', 'mysql')
$db_password = get_cloudify_attribute('password', 'service', 'hello-puppet', 'mysql')
$db_name = get_cloudify_attribute('db_name', 'service', 'hello-puppet', 'mysql')
$db_ip = get_cloudify_attribute('ip', 'service', 'hello-puppet', 'mysql')
file{ "$WEBAPP_PATH/config/database.yml":
    content => template('webapp/database.yml.erb'),
    require => Exec['bundle install'],
}

exec {'rake tasks':
    command => "bundle exec rake db:migrate RAILS_ENV=production",
    cwd     => "$WEBAPP_PATH",
    path    => "/usr/bin/:/usr/local/bin/:/bin/",
    require => File["$WEBAPP_PATH/config/database.yml"],
}

#This doesn't work well, I should move it to upstart - https://github.com/edrex/puppet-upstart
exec {'launch unicorn':
    command => "pgrep -f unicorn -P 1 || unicorn_rails -D -E production",
    cwd     => "$WEBAPP_PATH",
    path    => "/usr/bin/:/usr/local/bin/:/bin/",
    require => Exec['rake tasks', 'generate secret'],
}

exec {'disable default vhost':
    command => "/usr/sbin/a2dissite default",
    require => Package['apache']
}

apache::vhost { 'webapp':
  template => 'webapp/webapp.erb',
  require => Exec['rake tasks', 'generate secret', 'disable default vhost'],
}
