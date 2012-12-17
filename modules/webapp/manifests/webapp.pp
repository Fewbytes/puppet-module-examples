$WEBAPP_REPO="https://github.com/redmine/redmine.git" #TODO: set from cloudify
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

exec {'fetch webapp':
    command => "git clone $WEBAPP_REPO $WEBAPP_PATH",
    path    => "/usr/bin/:/usr/local/bin/:/bin/",
    creates => "$WEBAPP_PATH",
    require => File['/opt/webapps'],
}

exec { "add mysql gems":
  command => "echo \"gem 'mysql2'\" >>$WEBAPP_PATH/Gemfile",
  unless  => "grep 'mysql2' $WEBAPP_PATH/Gemfile",
  path    => "/usr/bin/:/usr/local/bin/:/bin/",
  require => Exec['fetch webapp']
}

exec {'bundle install':
    cwd     => "$WEBAPP_PATH",
    path    => "/usr/bin/:/usr/local/bin/:/bin/",
    require => Exec['fix gem dates', "add mysql gems"]
}

exec {'generate secret':
    command => "printf 'Blog::Application.config.secret_token = \"%s\"\n' `bundle exec rake secret` >$WEBAPP_PATH/config/initializers/the_secret_token.rb",
    cwd     => "$WEBAPP_PATH",
    path    => "/usr/bin/:/usr/local/bin/:/bin/",
    require => Exec['bundle install'],
    creates => "$WEBAPP_PATH/config/initializers/the_secret_token.rb",
}

exec {'fix new-style hashes': #only needed because we want to also support ruby 1.8
    command => "sed -i 's/key:/:key =>/g' $WEBAPP_PATH/config/initializers/session_store.rb; sed -i 's/format:/:format =>/g' $WEBAPP_PATH/config/initializers/wrap_parameters.rb",
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
    command => "bundle exec rake db:migrate RAILS_ENV=production && bundle exec rake assets:precompile",
    cwd     => "$WEBAPP_PATH",
    path    => "/usr/bin/:/usr/local/bin/:/bin/",
    require => [Exec['fix new-style hashes'], File["$WEBAPP_PATH/config/database.yml"]],
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
