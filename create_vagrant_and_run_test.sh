#!/bin/bash
set -e -x -u

BUILD_TO_RUN_PATH=$1
TEST_INFRA_PATH=$2
TMP_FOLDER_PATH=`pwd`
VM_NAME=default

# best effort to command in critical section
function lock {
  LOCKFILE=/run/shm/vagrantup.lock
  FLOCKTIMEOUT=600
  if which flock ; then
    (
      # Using the fd form of flock so that we can insert a sleep inside the
      # lock.
      flock -w $FLOCKTIMEOUT -x 42
      sleep 2
      $*
    ) 42>$LOCKFILE
  else
    $*
  fi
}

if [[ ! -f ~/boxes/ci_with_warden_prereqs.box ]]; then
  echo "NO vagrant box found in ~/boxes, you probably need to run create_vagrant_box.sh first!"
  exit 1
fi

cat <<EOF >Vagrantfile
  Vagrant.configure("2") do |config|
    config.ssh.username = "travis"
    config.vm.define "$VMNAME"
    config.vm.box = "ci_with_warden_prereqs"
    config.vm.box_url = "~/boxes/ci_with_warden_prereqs.box"
  end
EOF

lock vagrant up

vagrant ssh-config > ssh_config
ssh -F ssh_config $VM_NAME 'mkdir -p ~/workspace'
rsync -rq --rsh="ssh -F ssh_config" $BUILD_TO_RUN_PATH/.git/ $VM_NAME:workspace/.git
rsync -rq --rsh="ssh -F ssh_config" $TEST_INFRA_PATH/start_warden.sh $VM_NAME:workspace/
ssh -F ssh_config $VM_NAME 'cd ~/workspace && git checkout .'

echo "Your vagrant box is now provisioned in folder $TMP_FOLDER_PATH! Don't forget to vagrant destroy it eventually."
echo "To connect: vagrant ssh $VM_NAME"
echo "To destroy: vagrant destroy $VM_NAME"

if [ -z $NOTEST ]; then
  vagrant ssh $VM_NAME -c "cd ~/workspace &&         \
    env WARDENIZED_SERVICE=$WARDENIZED_SERVICE       \
    REQUIRE_PACKAGE=$REQUIRE_PACKAGE             \
    FOLDER_NAME=$FOLDER_NAME                     \
    ./.travis.run"
fi
