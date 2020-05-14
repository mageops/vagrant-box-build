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
  python \
  python2-PyMySQL \
  python2-pip \
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
  zswap_enabled=1 \
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
/dev/sr0 /mnt/dvd iso9660 defaults,noauto 0 1
"

log_step "Install extra repositories" \
  yum -y install \
    epel-release \
    elrepo-release \
    dnf

log_step "Enable Extra repositories" \
  yum-config-manager --enable \
    elrepo-kernel \
    epel \
    centos-ansible-29 \
      >/dev/null

###
# Note: We're using DNF as it's much faster
###
log_step "Update system" \
  dnf -y update

log_step "Install packages" \
  dnf -y install $PACKAGES

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
  dnf clean all

log_step "Disable swapfile" \
  swapoff -a

log_step "Remove swapfile" \
  rm -f /swapfile

log_step "Backup fstab" \
  cp -vf /etc/fstab /etc/fstab.bkp  

log_step "Configure new fstab" \
  echo "$FSTAB" > /etc/fstab











