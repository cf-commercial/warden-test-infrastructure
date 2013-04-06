#!/bin/bash
set -e -u -x
(
  git clone --depth=1 --quiet --branch=master git://github.com/cloudfoundry/warden.git vendor/warden
  cd vendor/warden

  # Ignore this project's BUNDLE_GEMFILE
  unset BUNDLE_GEMFILE

  # Close stdin
  exec 0>&-

  # Remove remnants of apparmor (specific to Travis VM)
  sudo dpkg --purge apparmor

  # Install dependencies
  # sudo apt-get -y install debootstrap quota

  cd warden
  rvmsudo bundle install

  # Download and extract the warden rootfs
  rvmsudo bundle exec rake setup:bin[config/linux.yml]
  mkdir -p /tmp/warden/rootfs
  curl -s http://d31qcsjlqa9q7y.cloudfront.net/lucid64.latest.tgz | sudo tar xzf - -C /tmp/warden/rootfs

  rvmsudo bundle exec rake warden:start[config/linux.yml] --trace >/dev/null 2>&1 &
)

# Wait for warden to come up
while [ ! -e /tmp/warden.sock ]
do
  sleep 1
done

echo "/tmp/warden.sock exists, let's run the specs"
