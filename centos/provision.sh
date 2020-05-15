#!/usr/bin/env bash

set -eu

log_step() { local NAME="$1"; shift; echo -en "\n  * $NAME: " >&2;  printf "%q " "$@" >&2; echo >&2; "$@" ; }

PACKAGES="\
  atop \
  bind-utils \
  curl \
  gdb \
  git \
  htop \
  iotop \
  jq \
  mc \
  nano \
  nc \
  nmap \
  psmisc \
  python3 \
  python3-virtualenv \
  python3-pip \
  rsync \
  socat \
  strace \
  sysstat \
  unzip \
  vim \
  wget \
  yum-plugin-verify \
  yum-utils \
  kernel-ml \
  kernel-ml-devel \
  cloud-utils-growpart \
  xfsprogs
"

# Pick a better-suited scheduler that is available in 5.6 kernel
KERNEL_IO_SCHEDULER="mq-deadline"

# Extend the default kernel args
KERNEL_CMDLINE="\
  no_timer_check \
  console=tty0 \
  console=ttyS0,115200n8 \
  net.ifnames=0 \
  biosdevname=0 \
  crashkernel=auto \
  elevator=${KERNEL_IO_SCHEDULER} \
  zswap.enabled=1 \
  zswap.compressor=lz4 \
  zswap.max_pool_percent=40 \
"

# Disable CPU bug mitigations
KERNEL_CMDLINE="$KERNEL_CMDLINE $(curl -Ls https://make-linux-fast-again.com)"

# Kernel modules needed for boot
VIRTUALBOX_MODULES_LOAD="
  # Virtualbox LSILogic SCSI controller
  mptspi
  mptscsih
  mptbase

  # Other virt modules
  virtio-pci
  virtio-net
"

FSTAB="
###
# --- Configured by vagrant provisioner ---
##
# Note: We always want to boot off the first harddrive and the UUID
# can change so instead lets use the device directly.
###
# Note: Unfortunately the old version of systemd (<236) in CentOS 7 has neither
# x-systemd.makefs nor x-systemd.growfs so we'll have to manually make the swapfs
# an grow the root partition later.. This options are added anyway for the future.
###
/dev/sda1 / xfs defaults,x-systemd.growfs 0 0
/dev/sdb none swap defaults,x-systemd.makefs 0 1
# Do not remove, see: /usr/local/bin/virtualbox-update-dvd-additions.sh
/dev/sr0 /mnt/dvd iso9660 defaults,auto,user 0 1
"

FASTESTMIRROR="
[main]
enabled=1
verbose=0
always_print_best_host = true
socket_timeout=3
hostfilepath=timedhosts.txt
maxhostfileage=1
maxthreads=15
"

VBOX_ADDITIONS_UPDATE_SCRIPT='
#!/bin sh

###
# Service - Installs VirtualBox Guest Additions from DVD
#
# Licensed under MIT -
# Copyright 2020 (c) creativestyle Polska Sp.z.o.o <https://creativestyle.pl>
# Copyright 2020 (c) Filip Sobalski <filip.sobalski@creativestyle.pl>
###
# Note: Should be started from systemd unit after DVD is mounted.
# See: /etc/systemd/system/virtualbox-update-dvd-additions.service
###

VBOX_GUEST_ADDITIONS_DVD_MOUNTPOINT="${VBOX_GUEST_ADDITIONS_DVD_MOUNTPOINT:-/mnt/dvd}"
VBOX_GUEST_ADDITIONS_INSTALLER_FILENAME="${VBOX_GUEST_ADDITIONS_INSTALLER_FILENAME:-VBoxLinuxAdditions.run}"
VBOX_GUEST_ADDITIONS_DVD_INSTALLER_PATH="$VBOX_GUEST_ADDITIONS_DVD_MOUNTPOINT/$VBOX_GUEST_ADDITIONS_INSTALLER_FILENAME"

if [ -x "${VBOX_GUEST_ADDITIONS_DVD_INSTALLER_PATH}" ] ; then
  echo "[SUCCESS] VBox Guest Additions DVD Installer found"

  "$VBOX_GUEST_ADDITIONS_DVD_INSTALLER_PATH"      && echo "[SUCCESS] Run installer"
  eject "$VBOX_GUEST_ADDITIONS_DVD_MOUNTPOINT"    && echo "[SUCCESS] Eject DVD"

  echo "[NOTICE] Reboot the system to get the update modules!" >&2
else
  echo "[WARNING] VBox Guest Additions DVD Installer not found at: ${VBOX_GUEST_ADDITIONS_DVD_INSTALLER_PATH}" >&2
fi
'

VBOX_ADDITIONS_UPDATE_SERVICE='
[Unit]
Description=Install VirtualBox Guest Additions from DVD
ConditionPathExists=/mnt/dvd/VBoxLinuxAdditions.run
After=mnt-dvd.mount

[Service]
Type=oneshow
ExecStart=/usr/local/bin/virtualbox-update-dvd-additions.sh
RemainAfterExit=yes
Environment=VBOX_GUEST_ADDITIONS_DVD_MOUNTPOINT=/mnt/dvd
Environment=VBOX_GUEST_ADDITIONS_INSTALLER_FILENAME=VBoxLinuxAdditions.run

[Install]
WantedBy=multi-user.target
'

install_vbox_additions_dvd_updater() {
  log_step "Install the additions updater service unit file" \
    echo "$VBOX_ADDITIONS_UPDATE_SERVICE" > /etc/systemd/system/virtualbox-update-dvd-additions.service

  log_step "Install the additions updater service script" \
    echo "$VBOX_ADDITIONS_UPDATE_SCRIPT" > /usr/local/bin/virtualbox-update-dvd-additions.sh

  log_step "Make the additions updater service script executable" \
    chmod +x /usr/local/bin/virtualbox-update-dvd-additions.sh

  log_step "Reload systemd daemon" \
    systemctl daemon-reload

  log_step "Start and enable the additions updater service" \
    systemctl enable --now virtualbox-update-dvd-additions
}

log_step "Install extra repositories" \
  yum -y install \
    epel-release \
    elrepo-release \
    yum-plugin-fastestmirror

log_step "Install fastestmirror config" \
  echo "$FASTESTMIRROR" \
    >/etc/yum/pluginconf.d/fastestmirror.conf

log_step "Remove fastestmirror cache" \
   find /var/cache/yum/ -iname 'timedhosts*' -exec rm -vf {} \;

log_step "Enable Extra repositories" \
  yum-config-manager --enable \
    elrepo-kernel \
    epel \
    centos-ansible-29 \
      >/dev/null

log_step "Update system" \
  yum -y update

log_step "Install packages" \
  yum -y install $PACKAGES

log_step "Set Grub boot entry to use new kernel" \
  grub2-set-default 0 \
    >/dev/null

log_step "Set new kernel cmdline" \
  sed -i -E 's/^(GRUB_CMDLINE_LINUX=.*)$/\n# Original Before Vagrant Modifications\n# \1\n\n# Vagrant Modifications - Optimized\nGRUB_CMDLINE_LINUX="'"${KERNEL_CMDLINE}"'"\n/g' /etc/default/grub

log_step "Configure boot modules for Virtualbox" \
  echo "$VIRTUALBOX_MODULES_LOAD" \
    > /etc/modules-load.d/virtualbox.conf

ls -1 /lib/modules | while read KERNEL ; do
  log_step "Rebuild initramfs for kernel $KERNEL" \
    dracut --force "/boot/initramfs-$KERNEL.img" "$KERNEL"
done

log_step "Rebuild grub cfg" \
  grub2-mkconfig -o /boot/grub2/grub.cfg

log_step "Clean YUM caches" \
  yum clean all

log_step "Clean DNF caches" \
  yum clean all

log_step "Disable swapfile" \
  swapoff -a

log_step "Remove swapfile" \
  rm -f /swapfile

log_step "Backup fstab" \
  cp -vf /etc/fstab /etc/fstab.bkp

log_step "Configure new fstab" \
  echo "$FSTAB" > /etc/fstab

log_step "Remove fastestmirror cache so it's rebuilt for next user" \
  find /var/cache/yum/ -iname 'timedhosts*' -exec rm -vf {} \;

log_step "Disable selinux now" \
  setenforce 0

log_step "Disable selinux permanently" \
  sed -Ei 's/^ *SELINUX=.*$/SELINUX=disabled/g' /etc/sysconfig/selinux

log_step "Disable selinux service" \
  systemctl disable selinux-policy-migrate-local-changes@targeted.service

log_step "Install VirtualBox Guest Additions Updater" \
  install_vbox_additions_dvd_updater









