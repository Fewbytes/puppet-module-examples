$WEBAPP_PATH='/opt/webapps/rails'
$RAILS_DIR="$WEBAPP_PATH/guides/code/getting_started"

package {["rubygems", "ruby-dev", "libxml2-dev", "libxslt-dev", "libsqlite3-dev"]: }
package {"nodejs":} #used for its js runtime engine

exec {'fix gem dates':
    command => "/bin/sed -i 's/ 00:00:00.000000000Z//g' /var/lib/gems/1.8/specifications/*",
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
    command => "git clone https://github.com/rails/rails.git $WEBAPP_PATH",
    path    => "/usr/bin/:/usr/local/bin/:/bin/",
    creates => "$WEBAPP_PATH",
    require => File['/opt/webapps'],
}

exec {'bundle install':
    cwd     => "$RAILS_DIR",
    path    => "/usr/bin/:/usr/local/bin/:/bin/",
    require => Exec['fix gem dates'],
}

exec {'generate secret':
    command => "printf 'Blog::Application.config.secret_token = \"%s\"\n' `bundle exec rake secret` >config/initializers/secret_token.rb",
    cwd     => "$RAILS_DIR",
    path    => "/usr/bin/:/usr/local/bin/:/bin/",
    require => Exec['bundle install'],
    creates => "$RAILS_DIR/config/initializers/secret_token.rb",
}

exec {'rake tasks':
    command => "bundle exec rake db:migrate RAILS_ENV=production && bundle exec rake assets:precompile",
    cwd     => "$RAILS_DIR",
    path    => "/usr/bin/:/usr/local/bin/:/bin/",
    require => Exec['bundle install'],
}

exec {'launch unicorn':
    command => "pgrep -f unicorn || unicorn_rails -D -E production",
    cwd     => "$RAILS_DIR",
    path    => "/usr/bin/:/usr/local/bin/:/bin/",
    require => Exec['rake tasks', 'generate secret'],
}

apache::vhost { 'webapp':
  template => 'webapp/webapp.erb',
}
