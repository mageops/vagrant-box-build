set -eu

log_stage() { echo -e "\n  ---  $@  ---  \n"; }
log_step() { local NAME="$1"; shift; echo -en "  * $NAME: " >&2;  printf "%q " "$@" >&2; echo >&2; "$@" ; }

vm_info_fetch() {
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

vm_info_print() {
  env | sort | grep '^VM_'
}