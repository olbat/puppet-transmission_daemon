class transmission_daemon (
  $download_dir = "/var/lib/transmission-daemon/downloads",
  $incomplete_dir = undef,
  $rpc_url = undef,
  $rpc_port = 9091,
  $rpc_user = "transmission",
  $rpc_password = undef,
  $rpc_whitelist = undef,
  $blocklist_url = undef
) {
  $config_path = "/etc/transmission-daemon"

  package { 'transmission-daemon':
    ensure => installed,
  }

  exec { "stop-daemon":
    command => "/usr/sbin/service transmission-daemon stop", #or change to 
  }

  file { "${download_dir}":
    ensure => directory,
    recurse => true,
#    owner => "debian-transmission",
#    group => "debian-transmission",
#    mode => "ug+rw,u+x"
  }

  if $incomplete_dir {
    file { "${incomplete_dir}":
      ensure => directory,
      recurse => true,
#      owner => "debian-transmission",
#      group => "debian-transmission",
#      mode => "ug+rw,u+x"
    }
  }

  file { 'settings.json':
    path => "${config_path}/settings.json",
    ensure => file,
    require => [Package['transmission-daemon'],Exec['stop-daemon']],
    content => template("${module_name}/settings.json.erb"),
  }

  service { 'transmission-daemon':
    name => 'transmission-daemon',
    ensure => running,
    enable => true,
    hasrestart => true,
    hasstatus => true,
    subscribe => File['settings.json'],
  }

  if $rpc_url and $blocklist_url {
    if $rpc_password {
      $opt_auth = " --auth ${rpc_user}:${rpc_password}"
    }
    else
    {
      $opt_auth = ""
    }
    cron { 'update-blocklist':
      command => "/usr/bin/transmission-remote http://127.0.0.1:${rpc_port}/${rpc_url}${opt_auth}",
      user => root,
      hour => 2,
      minute => 0,
      require => Package['transmission-daemon'],
    }
  }
}
