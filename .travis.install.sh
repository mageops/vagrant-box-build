#!/usr/bin/env bash

set -eu

export BUILD_CACHE_DIR="${BUILD_CACHE_DIR:-$HOME/.build-cache}"
export VAGRANT_VERSION="${VAGRANT_VERSION:-2.2.9}" 
export VBOX_VERSION="${VBOX_VERSION:-6.1.1}"

VAGRANT_PACKAGE_URL="https://releases.hashicorp.com/vagrant/${VAGRANT_VERSION}/vagrant_${VAGRANT_VERSION}_x86_64.deb"
VBOX_PACKAGE_URL='https://download.virtualbox.org/virtualbox/6.1.6/virtualbox-6.1_6.1.6-137129~Ubuntu~bionic_amd64.deb'

VAGRANT_PACKAGE_PATH="$BUILD_CACHE_DIR/$(basename "$VAGRANT_PACKAGE_URL")"
VBOX_PACKAGE_PATH="$BUILD_CACHE_DIR/$(basename "$VBOX_PACKAGE_URL")"

mkdir -p "$BUILD_CACHE_DIR"

echo "* Begin Ubuntu setup for Vagrant/Virtualbox..."

echo "* Update system"
sudo apt -y update 

echo "* Install basic packages"
sudo apt -y install \
  build-essential \
  "linux-headers-$(uname -r)" \
  curl \
  bash

echo "* Download: $VAGRANT_PACKAGE_URL -> $VAGRANT_PACKAGE_PATH"
curl -L -o "$VAGRANT_PACKAGE_PATH"  "$VAGRANT_PACKAGE_URL"

echo "* Download: $VBOX_PACKAGE_URL -> $VBOX_PACKAGE_PATH"
curl -L -o "$VBOX_PACKAGE_PATH"     "$VBOX_PACKAGE_URL"

echo "* Install: $VAGRANT_PACKAGE_PATH $VBOX_PACKAGE_PATH"
sudo apt-get -y install \
  "$VAGRANT_PACKAGE_PATH" \
  "$VBOX_PACKAGE_PATH"

echo "* Build Virtualbox kernel modules"
sudo systemctl start vboxdrv

echo "✅ Vagrant and Virtualbox installed successfully"
echo "📦 VirtualBox version: $(VBoxManage --version)"
echo "📦 Vagrant version: $(vagrant --version)"

