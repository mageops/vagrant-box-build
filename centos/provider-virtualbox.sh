#!/usr/bin/env bash

export VM_ROOTDISK_SIZE="${VM_ROOTDISK_SIZE:-100000}"
export VM_ROOTDISK_FILENAME_RESIZED_VDI="rootdisk.vdi"
export VM_ROOTDISK_FILENAME_RESIZED_VMDK="rootdisk.vmdk"
export VM_SWAPDISK_SIZE="${VM_SWAPDISK_SIZE:-$(( VM_MEMORY / 4 * 3 ))}"
export VM_SWAPDISK_FILENAME="swapdisk.vmdk"

vagrant_provider_setup() {
  ###
  # WARNING: Provisioning has to be done before VM configuration as modules
  # for Virtualbox devices need to be loaded on boot (initramfs needs to 
  # be rebuilt) - otherwise system won't boot!
  ###
  log_stage "Configure the Virtualbox VM"

  log_step "Fetch VM information attributes" \
    eval "$(virtualbox_vm_info_fetch)"

  log_step "Stop the VM to adjust configuration" \
    vagrant halt

  ####
  # > Dragons ahead! If you need to modify the following code, then 
  # > you're in for a treat! VBoxManage is the most unintuitive,
  # > cryptic and buggy CLI tool I've ever used. Next time I would
  # > rather modify the .vbox or .ovf file directly...
  # -- Filip Sobalski
  ####
  if [ ! -z "${VM_ATTR_IDE_IMAGEUUID_0_0:-}" ] ; then
    log_stage "Upgrade IDE storage controller to SCSI"
    VM_ROOTDISK_UUID_OLD="$VM_ATTR_IDE_IMAGEUUID_0_0"

    ###
    # Note: I've tried hard and it's not possible to change the controller
    # type from IDE to SCSI using CLI (although with GUI it's one click),
    # so we have to:
    # -> remove the legacy IDE controller (thus detaching all disks)
    # -> create and SCSI controller
    # -> reattach the root disk to new new SCSI controller
    ###
    log_step "Remove IDE storage controller" \
      VBoxManage storagectl "$VM_NAME" \
        --name IDE \
        --remove

    ###
    # Note: The best option would be the `virtio-scsi` controller but 
    # Virtualbox support is experimental and thus the performance abysmal.
    ###
    # Warning: This has to be done *after* the initial provisioning
    # the as the disk UUID changes so the boot drive might not be found,
    # also the old, stock 3.x kernel might not work with this controller
    # at all.
    ###
    log_step "Create SCSI storage controller" \
      VBoxManage storagectl "$VM_NAME" \
        --name SCSI \
        --add scsi \
        --controller LSILogic \
        --hostiocache on \
        --bootable on

    log_stage "Resize root disk"

    ###
    # Virtualbox cannot resize VMDK disks but we want the box to be also
    # compatible with VMWare so we: 
    # -> convert to VDI 
    # -> resize VDI 
    # -> convert back to VMDK
    # -> attach to the new SCSI controller. 
    ###
    if [ ! -f "$VM_ROOTDISK_FILENAME_RESIZED_VDI" ] ; then
      log_step "Convert current root disk to VDI for resize" \
        VBoxManage clonemedium disk \
          "$VM_ROOTDISK_UUID_OLD" \
          "$VM_ROOTDISK_FILENAME_RESIZED_VDI" \
          --format VDI

      log_step "Delete old root disk image" \
          VBoxManage closemedium disk \
            "$VM_ROOTDISK_UUID_OLD" \
            --delete

      log_step "Resize VDI to ${VM_ROOTDISK_SIZE}MB" \
        VBoxManage modifymedium disk "$VM_ROOTDISK_FILENAME_RESIZED_VDI" \
          --resize "$VM_ROOTDISK_SIZE" \
          --compact \
          --description "Vagrant CentOS 7 RootFS Disk"
    fi

    if [ ! -f "$VM_ROOTDISK_FILENAME_RESIZED_VMDK" ] ; then
      log_step "Convert the VDI root disk image back to VMDK" \
        VBoxManage clonemedium disk \
          "$VM_ROOTDISK_FILENAME_RESIZED_VDI" \
          "$VM_ROOTDISK_FILENAME_RESIZED_VMDK" \
          --format VMDK \
          --variant Stream

      log_step "Delete the resized VDI root disk image" \
        VBoxManage closemedium disk \
          "$VM_ROOTDISK_FILENAME_RESIZED_VDI" \
          --delete
    fi
  fi

  log_step "Attach resized VMDK root disk to the new SCSI controller" \
    VBoxManage storageattach "$VM_NAME" \
        --storagectl SCSI \
        --device 0 \
        --port 0 \
        --type hdd \
        --mtype normal \
        --nonrotational on \
        --discard on \
        --medium "$VM_ROOTDISK_FILENAME_RESIZED_VMDK" \
        --comment "Linux rootfs disk"

  if [ "${VM_ATTR_SCSI_0_1:-none}" == "none" ] ; then
    log_stage "Add swap disk using fixed-size image"

    if [ ! -f "$VM_SWAPDISK_FILENAME" ] ; then 
      log_step "Create swap disk fixed-size image" \
        VBoxManage createmedium \
            disk \
            --size "$VM_SWAPDISK_SIZE" \
            --format VMDK \
            --variant FIXED \
            --filename "$VM_SWAPDISK_FILENAME"
    fi

    log_step "Attach swap disk to the SCSI controller" \
      VBoxManage storageattach "$VM_NAME" \
          --storagectl SCSI \
          --device 0 \
          --port 1 \
          --type hdd \
          --mtype writethrough \
          --nonrotational on \
          --discard on \
          --medium "$VM_SWAPDISK_FILENAME" \
          --comment "Fixed size Linux swap disk"
  fi

  if [ "${VM_ATTR_SCSI_0_2:-none}" == "none" ] ; then
    log_stage "Add a DVD drive for guest additions installation"

    log_step "Attach an empty DVD drive" \
      VBoxManage storageattach "$VM_NAME" \
        --storagectl SCSI \
        --device 0 \
        --port 2 \
        --type dvddrive \
        --medium emptydrive \
        --comment "Virtualbox Guest Additions DVD disk"
  fi

  log_step "Rename storage controller back to SCSI otherwise vagrant just breaks down" \
    VBoxManage storagectl "$VM_NAME" \
      --name SCSI \
      --rename IDE

  log_stage "Adjust VM configuration for stability and performance"

  log_step "Disable VM audio to avoid problems on macOS" \
    VBoxManage modifyvm "$VM_NAME" \
      --audio none

  log_step "Make the VM boot from disk only to speed up start" \
    VBoxManage modifyvm "$VM_NAME" \
      --boot1 disk \
      --boot2 none \
      --boot3 none \
      --boot4 none

  log_step "Change network adapter types to virtio-net" \
    VBoxManage modifyvm "$VM_NAME" \
      --nictype1 virtio \
      --nictype2 virtio \
      --nictype3 virtio \
      --nictype4 virtio

  log_step "Configure paravirtualization features" \
    VBoxManage modifyvm "$VM_NAME" \
      --cpu-profile host \
      --paravirtprovider kvm \
      --nestedpaging on \
      --pae on \
      --hpet on \
      --graphicscontroller vmsvga \
      --rtcuseutc on \
      --x2apic on \
      --biosapic x2apic \
      --vtxvpid on \
      --largepages on \
      --spec-ctrl on \
      --hwvirtex on \
      --nested-hw-virt on

  log_step "Start the VM back up" \
    vagrant up

  virtualbox_vm_system_info_print
}