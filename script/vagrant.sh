#!/bin/bash -eux

echo '==> Configuring settings for vagrant'

SSH_USER=${SSH_USERNAME:-vagrant}
SSH_PASSWORD=${SSH_PASSWORD:-vagrant}
SSH_USER_HOME=${SSH_USER_HOME:-/home/${SSH_USER}}

# https://raw.githubusercontent.com/mitchellh/vagrant/master/keys/vagrant.pub
SSH_KEY=${SSH_KEY:ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA6NF8iallvQVp22WDkTkyrtvp9eWW6A8YVr+kz4TjGYe7gHzIw+niNltGEFHzD8+v1I2YJ6oXevct1YeS0o9HZyN1Q9qgCgzUFtdOKLv6IedplqoPkcmF0aYet2PkEDo3MlTBckFXPITAMzF8dJSIFo9D8HfdOV0IAdx4O7PtixWKn5y2hMNG0zQPyUecp4pzC6kivAIhyfHilFR61RGL+GPXQ2MWZWFYbAGjyiYJnAmCP3NOTd0jMZEnDkbUvxhMmBYSdETk1rRgm+R4LOzFUGaHqHDLKLX+FIPKcF96hrucXzcWyLbIbEgE98OHlnVYCzRdK8jlqm8tehUc9c9WhQ== vagrant insecure public key}

# Packer passes boolean user variables through as '1', but this might change in
# the future, so also check for 'true'.
if [ "$INSTALL_SSH_KEY" = "true" ] || [ "$INSTALL_SSH_KEY" = "1" ]; then
  # Add vagrant user (if it doesn't already exist)
  if ! id -u $SSH_USER >/dev/null 2>&1; then
      echo '==> Creating ${SSH_USER}'
      /usr/sbin/groupadd $SSH_USER
      /usr/sbin/useradd $SSH_USER -g $SSH_USER -G wheel
      echo '==> Giving ${SSH_USER} sudo powers'
      echo "${SSH_PASSWORD}"|passwd --stdin $SSH_USER
      echo "${SSH_USER}        ALL=(ALL)       NOPASSWD: ALL" >> /etc/sudoers

  fi

  # Record the vagrant username if it's not already there to allow for testing
  if ! -f /etc/vagrant.uname; then
    echo '==> Recording the vagrant username'
    echo $SSH_USER > /etc/vagrant.uname
  fi

  echo '==> Installing SSH key'
  mkdir -pm 700 ${SSH_USER_HOME}/.ssh
  echo "${SSH_KEY}" > $SSH_USER_HOME/.ssh/authorized_keys
  chmod 0600 ${SSH_USER_HOME}/.ssh/authorized_keys
  chown -R ${SSH_USER}:${SSH_USER} ${SSH_USER_HOME}/.ssh

fi

echo '==> Recording box config date'
date > /etc/box_build_time

echo '==> Customizing message of the day'
echo 'Welcome to your Packer-built virtual machine.' > /etc/motd
