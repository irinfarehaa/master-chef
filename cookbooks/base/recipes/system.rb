
include_recipe "base::apt"
include_recipe "base::apt_update"
include_recipe "base::apt_dist_upgrade"
include_recipe "base::bash"
include_recipe "base::editor"
include_recipe "base::sshd"
include_recipe "base::ntp"
include_recipe "base::timezone"
include_recipe "base::procps"
include_recipe "base::disable_ipv6"
include_recipe "base::resolv_conf"
include_recipe "base::limits"
include_recipe "base::users"
include_recipe "base::ssh_keys"
include_recipe "base::ssh_host_keys"
include_recipe "base::additional"
include_recipe "base::locales"
include_recipe "base::ubuntu_force_confold"
include_recipe "base::add_user_in_group"
include_recipe "base::symlink_folders"
include_recipe "base::purge_limits"

package "apt-transport-https" if node.lsb.id == 'Debian'

if node.lsb.codename == "xenial"
  hold_package_version "chef"
end

