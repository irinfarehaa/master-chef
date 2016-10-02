#!/bin/bash

WARP_ROOT="http://warp-repo.s3-eu-west-1.amazonaws.com"

if [ "$PROXY" != "" ]; then
  PROXY="http_proxy=$PROXY https_proxy=$PROXY"
fi

if [ "$MASTER_CHEF_URL" = "" ]; then
  MASTER_CHEF_URL="http://github.com/kitchenware/master-chef.git"
fi

if [ "$MASTER_CHEF_DIRECT_ACCESS_URL" = "" ]; then
  # non standard url. rawgithub.com support http, raw.github.com does not
  MASTER_CHEF_DIRECT_ACCESS_URL="http://rawgithub.com/kitchenware/master-chef"
fi

if [ "$MASTER_CHEF_HASH_CODE" = "" ]; then
  MASTER_CHEF_HASH_CODE="master"
else
  MASTER_CHEF_FIRST_RUN="GIT_TAG_OVERRIDE=\"$MASTER_CHEF_URL=$MASTER_CHEF_HASH_CODE\""
fi

print() {
  echo "/---------------------------------------------------------"
  echo "| $1"
  echo "\\---------------------------------------------------------"
}

print "Welcome into Master-Chef bootstraper !"

SUDO="sudo"
if [ "$USER" = "root" ]; then
  SUDO=""
else
  if ! $SUDO /bin/sh -c 'uname' > /dev/null; then
    echo "Cannot use sudo !"
    exit 1
  fi
fi

exec_command() {
  cmd="$*"
  sh -c "$cmd"
  if [ $? != 0 ]; then
    echo "Exection failed : $cmd"
    exit 2
  fi
}

exec_command_chef() {
  cmd="$*"
  sh -c "$SUDO sudo -H -u chef /bin/sh -c \"cd /home/chef && $cmd\""
  if [ $? != 0 ]; then
    echo "Execution failed for chef : $cmd"
    exit 2
  fi
}

install_master_chef_file() {
  file=$1
  target=$2
  url="$MASTER_CHEF_DIRECT_ACCESS_URL/$MASTER_CHEF_HASH_CODE/$file"
  echo "Downloading $url to $target"
  exec_command "$SUDO $PROXY curl -f -s -L $url -o $target"
}

install_master_chef_shell_file() {
  install_master_chef_file $1 $2
  exec_command "$SUDO chmod +x $2"
}

setup_keys (){
  if [ "$USER" != "chef" ]; then
    KEYS="$HOME/.ssh/authorized_keys"
    if [ -f $KEYS ]; then
      print "Installing credentials to chef account from $KEYS"
      exec_command "$SUDO cp $KEYS /home/chef/.ssh/authorized_keys"
    else
      KEYS="$HOME/.ssh/authorized_keys2"
      if [ -f $KEYS ]; then
        print "Installing credentials to chef account from $KEYS"
        exec_command "$SUDO cp $KEYS /home/chef/.ssh/authorized_keys"
      else
        echo "File not found $KEYS"
      fi
    fi
  fi

  exec_command "$SUDO chown -R chef /home/chef/.ssh"
}

while ps axu | grep cloud-init | grep -v grep; do
  echo "Wait end of cloud-init"
  sleep 2
done

arch=`arch`

echo "Detected architecture : $arch"

if [ "$arch" = "x86_64" ]; then
  opscode_dir="x86_64"
  arch="amd64"
elif [ "$arch" = "i686" ]; then
  opscode_dir="i686"
  arch="i386"
elif [ "$arch" = "ppc64le" ]; then
  arch="ppc64le"
elif [ "$arch" = "armv7l" ]; then
  arch="armv7l"
elif [ "$arch" = "armv6l" ]; then
  arch="armv6l"
else
  echo "Unknown arch $arch"
  exit 2
fi

if which apt-get > /dev/null; then

  print "Debian based distribution detected"

  exec_command "$SUDO $APT_PROXY apt-get update"

  if ! which lsb_release > /dev/null; then
    exec_command "$SUDO $APT_PROXY apt-get install -y lsb-release"
  fi

  distro=`lsb_release -cs`

  print "Detected distro : $distro"

  case $distro in
    wheezy)
      exec_command "$SUDO $APT_PROXY apt-get install -y rsync git-core curl bzip2 unzip sudo file"
      OMNIBUS_DEB="http://opscode-omnibus-packages.s3.amazonaws.com/debian/6/${opscode_dir}/chef_11.16.4-1_${arch}.deb"
      if [ "$arch" = "armv7l" ]; then
        OMNIBUS_DEB="https://github.com/bpaquet/chef_for_rasberry_pi/raw/master/chef_11.16.4-1_armhf.deb"
      fi
      if [ "$arch" = "armv6l" ]; then
        OMNIBUS_DEB="https://github.com/bpaquet/chef_for_rasberry_pi/raw/master/chef_11.16.4-1_armv6l.deb"
      fi
     ;;
    jessie)
      exec_command "$SUDO $APT_PROXY apt-get install -y rsync git-core curl bzip2 unzip sudo file"
      OMNIBUS_DEB="http://opscode-omnibus-packages.s3.amazonaws.com/debian/6/${opscode_dir}/chef_11.16.4-1_${arch}.deb"
      ;;
    precise)
      exec_command "$SUDO $APT_PROXY apt-get install -y rsync git-core curl bzip2 unzip"
      OMNIBUS_DEB="http://opscode-omnibus-packages.s3.amazonaws.com/ubuntu/12.04/${opscode_dir}/chef_11.8.0-1.ubuntu.12.04_${arch}.deb"
      ;;
    trusty|xenial)
      exec_command "$SUDO $APT_PROXY apt-get install -y rsync git-core curl bzip2 unzip"
      OMNIBUS_DEB="https://opscode-omnibus-packages.s3.amazonaws.com/ubuntu/13.04/${opscode_dir}/chef_11.16.4-1_amd64.deb"
      if [ "$arch" = "ppc64le" ]; then
        OMNIBUS_DEB="https://github.com/bpaquet/ppc64le/raw/master/chef_11.16.4+20150329005250-1_ppc64el.deb"
      fi
      if [ "$arch" = "armv7l" ]; then
        OMNIBUS_DEB="https://github.com/bpaquet/chef_for_rasberry_pi/raw/master/chef_11.16.4-1_armhf.deb"
      fi
      if [ "$arch" = "armv6l" ]; then
        OMNIBUS_DEB="https://github.com/bpaquet/chef_for_rasberry_pi/raw/master/chef_11.16.4-1_armv6l.deb"
      fi
      if [ "$arch" = "i386" ]; then
        OMNIBUS_DEB="https://opscode-omnibus-packages.s3.amazonaws.com/ubuntu/13.04/i686/chef_11.16.4-1_i386.deb"
      fi
      ;;
    *)
      echo "Unknown distro"
      exit 78
  esac

  exec_command "cat /etc/passwd | grep ^chef > /dev/null || $SUDO useradd -m -g sudo -s /bin/bash chef"
  exec_command "$SUDO cat /etc/sudoers | grep ^chef > /dev/null || $SUDO /bin/sh -c 'echo \"chef   ALL=(ALL) NOPASSWD:ALL\" >> /etc/sudoers'"
  exec_command "$SUDO mkdir -p /home/chef/.ssh/"

  setup_keys
  print "Installing chef from Omnibus"

  if [ "$OMNIBUS_DEB" = "" ]; then
    echo "Omnibus url not set for this distro : $distro"
    exit 42
  fi

  exec_command_chef "[ -f `basename $OMNIBUS_DEB` ] || $PROXY curl -f -s -L \"$OMNIBUS_DEB\" -o `basename $OMNIBUS_DEB`"
  exec_command_chef "sudo dpkg -i `basename $OMNIBUS_DEB`"
elif which yum > /dev/null; then
  distro=$(cat /etc/issue | head -1)
  print "Detected distro : $distro"
  if ! cat /etc/group | grep admin  > /dev/null; then
    exec_command "groupadd admin"
  fi

  if ! which git > /dev/null; then
    exec_command "$SUDO $PROXY yum install -y git"
  fi
  exec_command "$SUDO $PROXY yum install -y rsync curl wget bzip2 unzip"
  OMNIBUS_DEB="http://opscode-omnibus-packages.s3.amazonaws.com/el/6/x86_64/chef-11.16.4-1.el6.x86_64.rpm"

  exec_command "cat /etc/passwd | grep ^chef > /dev/null || $SUDO useradd -m -g admin -s /bin/bash chef"
  exec_command "$SUDO cat /etc/sudoers | grep ^chef > /dev/null || $SUDO /bin/sh -c 'echo \"chef   ALL=(ALL) NOPASSWD:ALL\" >> /etc/sudoers'"
  exec_command "$SUDO mkdir -p /home/chef/.ssh/"
  setup_keys

  print "Installing chef from Omnibus"
  if [ "$OMNIBUS_DEB" = "" ]; then
    echo "Omnibus url not set for this distro : $distro"
    exit 42
  fi

  exec_command_chef "[ -f `basename $OMNIBUS_DEB` ] || $PROXY curl -f -s -L \"$OMNIBUS_DEB\" -o `basename $OMNIBUS_DEB`"
  exec_command_chef "sudo rpm -ivh `basename $OMNIBUS_DEB`"
fi

if [ "$distro" = "" ]; then
  echo "Unknown distro"
  exit 78
fi


exec_command "$SUDO mkdir -p /opt/master-chef/etc"
install_master_chef_file "cookbooks/master_chef/templates/default/solo.rb.erb" "/opt/master-chef/etc/solo.rb"
$SUDO sed -i '/^<%/d' "/opt/master-chef/etc/solo.rb"
$SUDO sed -i '/REMOVE_DURING_BOOSTRAP/d' "/opt/master-chef/etc/solo.rb"

exec_command_chef "echo '{\\\"repos\\\":{\\\"git\\\":[\\\"$MASTER_CHEF_URL\\\"]},\\\"run_list\\\":[\\\"recipe[master_chef::chef_solo_scripts]\\\"],\\\"node_config\\\":{}}' | sudo tee /opt/master-chef/etc/local.json > /dev/null"

print "Bootstraping master-chef, using url $MASTER_CHEF_URL"

exec_command_chef "VAR_CHEF=/opt/chef/var GIT_CACHE_DIRECTORY=/opt/master-chef/var/git_repos $PROXY $MASTER_CHEF_FIRST_RUN MASTER_CHEF_CONFIG=/opt/master-chef/etc/local.json sudo -E /opt/chef/bin/chef-solo -c /opt/master-chef/etc/solo.rb"

print "Master-chef Ready !!!!!!!"