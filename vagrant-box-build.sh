#!/usr/bin/env bash

source ./vagrant-virtualbox-utils.sh

export VM_NAME="${VM_NAME:-vagrant-raccoon-base}"
export VM_CPUS=${VM_CPUS:-2}
export VM_MEMORY=${VM_MEMORY:-2048}
export VM_ROOTDISK_SIZE="${VM_ROOTDISK_SIZE:-100000}"
export VM_ROOTDISK_FILENAME_RESIZED_VDI="rootdisk.vdi"
export VM_ROOTDISK_FILENAME_RESIZED_VMDK="rootdisk.vmdk"
export VM_SWAPDISK_SIZE="${VM_SWAPDISK_SIZE:-$(( VM_MEMORY / 4 * 3 ))}"
export VM_SWAPDISK_FILENAME="swapdisk.vmdk"

log_stage "Perform basic machine setup"

# log_step "Start and provision the machine" \
#   vagrant up \
#     --provider=virtualbox \
#     --provision

###
# WARNING: Provisioning has to be done before VM configuration as modules
# for Virtualbox devices need to be loaded on boot - initramfs is rebuilt 
# - otherwise system won't boot!
###
./vagrant-vm-configure.sh

INFO_SCRIPT='
  echo -e "--- Machine info ($(date)) --- \n"
  echo -e "\n --- Kernel --- \n$(uname -a | sed -e "s/^/   < /g")"
  echo -e "\n --- Kernel commandline --- \n$(cat /proc/cmdline | sed -e "s/^/   < /g")"
  echo -e "\n --- Memory --- \n$(free -m | sed -e "s/^/   < /g")"
  echo -e "\n --- Mounts --- \n$(mount | sort | sed -e "s/^/   < /g")"
  echo -e "\n --- Disks --- \n$(lsblk | sed -e "s/^/   < /g")"
  echo -e "\n --- Disk space --- \n$(df -h | sed -e "s/^/   < /g")"
  echo -e "\n --- fstab --- \n$(cat /etc/fstab | sed -e "s/^/   < /g")"
  echo -e "\n --- PCI devices --- \n$(lspci | sed -e "s/^/   < /g")"
  echo -e "\n --- Storage devices ---  \n$(ls -l /sys/dev/block/* | sed -e "s/^/   < /g")"
  echo -e "\n --- Network devices ---  \n$(ip a l | sed -e "s/^/   < /g")"
  echo -e "\n --- Grub boot entries --- \n$(sudo grep "^menuentry" /boot/grub2/grub.cfg | cut -d'"\\'"' -f2 | sed -e "s/^/   < /g")"
'

vagrant ssh -c "$(echo $INFO_SCRIPT)"



