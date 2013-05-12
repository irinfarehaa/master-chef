#!/bin/bash

source `dirname $0`/install_chef_common.sh

if [ "$INSTALL_USER" = "" ]; then
  INSTALL_USER="admin"
fi

read -r -d '' INIT_SCRIPT <<EOF

mkdir -p \$HOME/.ssh &&

echo $KEY > \$HOME/.ssh/authorized_keys &&

useradd -m -g sudo -s /bin/bash chef &&

$PROXY apt-get -y update &&
$PROXY apt-get -y install git-core curl bzip2 sudo file lsb-release &&
$PROXY apt-get clean &&

echo "chef   ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers &&

mkdir -p /home/chef/.ssh/ &&
cp \$HOME/.ssh/authorized_keys /home/chef/.ssh/authorized_keys &&
chown -R chef /home/chef/.ssh

EOF

WARP_FILE="ruby_wheezy_x86_64_ree-1.8.7-2012.01_rbenv_chef.warp"

chef_install
