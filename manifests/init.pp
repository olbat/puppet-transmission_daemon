# = Class: transmission_daemon
# 
# This class installs/configures/manages the transmission-daemon bittorrent client. It can configure an RPC bittorrent client (web).
# 
# == Parameters: 
#
# $download_dir:: The directory where the files have to be downloaded. Defaults to +/var/lib/transmission-daemon/downloads+.
# $incomplete_dir:: The temporary directory used to store incomplete files. The feature is disabled when the option is not set. By default this feature is disabled.
# $rpc_url:: The access path to the RPC server (web). The feature is disabled when the option is not set. This path should not finish with the / (slash) char. By default this feature is disabled.
# $rpc_port:: The port the RPC server is listening on. Defaults to +9091+.
# $rpc_user:: The RPC user (ACL). Defaults to +transmission+.
# $rpc_password:: The password of the RPC user (ACL). By default this option is not set.
# $rpc_whitelist:: An array of IP addresses. This list define which machines are allowed to use the RPC interface. It is possible to use wildcards in the addresses. By default the list is empty.
# $blocklist_url:: An url to a block list. By default this option is not set.
# $script_torrent_done:: Launch a script at torrent completion (see https://trac.transmissionbt.com/wiki/Scripts). By default this option is not set.
#
# == Requires: 
# 
# Nothing.
# 
# == Sample Usage:
#
#  class {'transmission_daemon':
#    download_dir => "/var/lib/transmission-daemon/downloads",
#    incomplete_dir => "/tmp/downloads",
#    rpc_url => "bittorrent/",
#    rpc_port => 9091,
#    rpc_whitelist => ['127.0.0.1'],
#    blocklist_url => 'http://list.iblocklist.com/?list=bt_level1',
#    script_torrent_done => 'puppet:///modules/transmission_daemon/torrent-done.sh',
#  }
#
class transmission_daemon (
  $download_dir = "/var/lib/transmission-daemon/downloads",
  $incomplete_dir = undef,
  $rpc_url = undef,
  $rpc_port = 9091,
  $rpc_user = "transmission",
  $rpc_password = undef,
  $rpc_whitelist = undef,
  $blocklist_url = undef,
  $script_torrent_done = undef
) {
  $config_path = "/etc/transmission-daemon"
  $script_done = "${config_path}/torrent-done.sh"

  package { 'transmission-daemon':
    ensure => installed,
  }

  exec { "stop-daemon":
    command => "/usr/sbin/service transmission-daemon stop", #or change to 
  }

  file { "${download_dir}":
    ensure => directory,
    recurse => true,
    require => Package['transmission-daemon'],
#    owner => "debian-transmission",
#    group => "debian-transmission",
#    mode => "ug+rw,u+x"
  }

  if $incomplete_dir {
    file { "${incomplete_dir}":
      ensure => directory,
      recurse => true,
      require => Package['transmission-daemon'],
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
      command => "/usr/bin/transmission-remote http://127.0.0.1:${rpc_port}${rpc_url}${opt_auth} --blocklist-update 2>&1 > /tmp/blocklist-update.log",
      user => root,
      hour => 2,
      minute => 0,
      require => Package['transmission-daemon'],
    }
  }

  if $script_torrent_done {
    file { 'torrent-done.sh':
      path => $script_done,
      ensure => file,
      mode => "+x",
      source => $script_torrent_done,
      before => File['settings.json'],
      require => Package['transmission-daemon'],
      notify => Service['transmission-daemon'],
    }
  }
}
