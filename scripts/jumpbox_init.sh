#!/bin/bash
set -e

echo "export TERM=xterm-256color" | sudo tee /etc/profile.d/set-term.sh

apt-get update -y
apt-get install -y postgresql-client git

# install azure-cli
curl -fsSL 'https://azurecliprod.blob.core.windows.net/$root/deb_install.sh' | sudo bash

git clone https://github.com/neutrollized/dynmotd

cd dynmotd
./install.sh


# Signal success
touch /tmp/jumpbox_init_done
