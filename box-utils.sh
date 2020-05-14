set -eu

log_stage() { echo -e "\n    [${VAGRANT_BOX:-box}] ---  $@  ---  \n"; }
log_step() { local NAME="$1"; shift; echo -en "  * [${VAGRANT_BOX:-box}] $NAME: \n    $ " >&2;  printf "%q " "$@" >&2; echo >&2; "$@" ; }

virtualbox_vm_info_fetch() {
  local NAME="${1:-${VM_NAME}}"
  local ATTR_STR
  local ATTR_NAME
  local ATTR_VALUE

  VBoxManage showvminfo "${NAME}" --machinereadable \
    | sort \
    | while read ATTR_STR
  do
    ATTR_NAME="$(echo "$ATTR_STR" | cut -d= -s -f1 - | tr '[:lower:]' '[:upper:]' | sed -E 's/[^_A-Z0-9]+/_/g' | sed -E 's/^_+|_+$//g')"
    ATTR_VALUE="$(echo "$ATTR_STR" | cut -d= -s -f2- - | sed -E 's/^"+|"+$//g')"

    echo "export VM_ATTR_${ATTR_NAME}='$ATTR_VALUE';"
  done
}

virtualbox_vm_info_print() {
  env | sort | grep '^VM_'
}

virtualbox_vm_system_info_print() {
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
}