#Deploys a rail webapp as defined in facts loaded from (service-scope) cloudify attributes:
#   $service_webapp_repo - the git repo to clone
#   $service_webapp_tag  - the tag to checkout

$WEBAPP_PATH="/opt/webapps/rails"

package {["rubygems", "ruby-dev", "libxml2-dev", "libxslt-dev", "libsqlite3-dev", "libmysqlclient-dev"]: }

package {"bundler":
    provider => gem,
    require => Package["rubygems"],
}

class {'apache': }
apache::module { 'proxy_http': }

file { '/opt/webapps':
    ensure => "directory",
}

exec {'fetch webapp repo':
    command => "git clone $service_webapp_repo $WEBAPP_PATH",
    path    => "/usr/bin/:/usr/local/bin/:/bin/",
    creates => "$WEBAPP_PATH",
    require => File['/opt/webapps'],
}

exec {'fetch webapp tag':
    command => "git checkout $service_webapp_tag",
    path    => "/usr/bin/:/usr/local/bin/:/bin/",
    cwd     => "$WEBAPP_PATH",
    require => Exec['fetch webapp repo'],
}

#set up unicorn
file { 'Gemfile.local':
    path => "$WEBAPP_PATH/Gemfile.local",
    content => "gem 'unicorn'\n",
    require => Exec['fetch webapp tag'],
}

exec {"bundle install":
    command => "bundle install --without development test rmagick postgresql",
    cwd     => "$WEBAPP_PATH",
    path    => "/usr/bin/:/usr/local/bin/:/bin/",
    require => [File['Gemfile.local'], Package["bundler"]],
}

exec {'generate secret':
    command => "bundle exec rake generate_session_store",
    cwd     => "$WEBAPP_PATH",
    path    => "/usr/bin/:/usr/local/bin/:/bin/",
    require => Exec['bundle install'],
}

#use the mysql service for the production db
$db_user = get_cloudify_attribute('user', 'service', 'redmine-puppet', 'mysql')
$db_password = get_cloudify_attribute('password', 'service', 'redmine-puppet', 'mysql')
$db_name = get_cloudify_attribute('db_name', 'service', 'redmine-puppet', 'mysql')
$db_ip = get_cloudify_attribute('ip', 'service', 'redmine-puppet', 'mysql')
file{ "$WEBAPP_PATH/config/database.yml":
    content => template('webapp/database.yml.erb'),
    require => Exec['bundle install'],
}

exec {'rake tasks':
    command => "bundle exec rake db:migrate RAILS_ENV=production && bundle exec rake redmine:load_default_data RAILS_ENV=production REDMINE_LANG=en",
    cwd     => "$WEBAPP_PATH",
    path    => "/usr/bin/:/usr/local/bin/:/bin/",
    require => [File["$WEBAPP_PATH/config/database.yml"], Exec['generate secret']],
}

#TODO: create a redmine user and give it file system permissions?
#mkdir tmp tmp/pdf public/plugin_assets
#chown -R redmine:redmine files log tmp public/plugin_assets
#chmod -R 755 files log tmp public/plugin_assets

#This doesn't work well, I should move it to upstart - https://github.com/edrex/puppet-upstart
exec {'launch unicorn':
    command => "pgrep -f unicorn -P 1 || bundle exec unicorn_rails -D -E production",
    cwd     => "$WEBAPP_PATH",
    path    => "/usr/bin/:/usr/local/bin/:/bin/",
    require => [Exec['rake tasks', 'generate secret'], File['Gemfile.local']],
}

exec {'disable default vhost':
    command => "/usr/sbin/a2dissite default",
    require => Package['apache']
}

apache::vhost { 'webapp':
  template => 'webapp/webapp.erb',
  require => Exec['rake tasks', 'generate secret', 'disable default vhost'],
}
