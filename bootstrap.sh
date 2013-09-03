#!/usr/bin/env bash

# Set the USER and HOME variables to be the vagrant user. By default, the script is run as root
export USER='vagrant'
export HOME='/home/vagrant'

# Install some necessary packages
sudo apt-get install -y redis-server curl git make g++

# Install NVM. Use source ~/.profile to "restart" the shell
curl https://raw.github.com/creationix/nvm/master/install.sh | sh
source $HOME/.profile

nvm install 0.10
nvm alias default 0.10

npm install -g coffee-script grunt-cli

# Rebuild 
cd /vagrant
npm rebuild
