#!/usr/bin/env bash

source ./box-utils.sh

export VAGRANT_BOX="${1:-${VAGRANT_BOX:-centos}}"
export VAGRANT_PROVIDER="${2:-${VAGRANT_PROVIDER:-virtualbox}}"
export VAGRANT_DIR="${3:-${VAGRANT_DIR:-./${VAGRANT_BOX}}}"
export VAGRANT_CLOUD_BOX="${VAGRANT_CLOUD_BOX:-${VAGRANT_CLOUD_ORG}/${VAGRANT_BOX}}"
export VAGRANT_CLOUD_BOX_VERSION="${VAGRANT_CLOUD_BOX_VERSION:-$(date '+%Y.%m%d.%H%M')}"

export VAGRANT_PROVIDER_SCRIPT="${VAGRANT_PROVIDER_SCRIPT:-provider-${VAGRANT_PROVIDER}.sh}"

export VM_NAME="${VM_NAME:-vagrant-mageops-${VAGRANT_BOX}}"
export VM_CPUS=${VM_CPUS:-2}
export VM_MEMORY=${VM_MEMORY:-2048}

log_stage "Begin machine ${VM_NAME}@${VAGRANT_PROVIDER} provisioning"

log_step "Enter vagrant directory" \
  pushd "$VAGRANT_DIR" >/dev/null

log_step "Upgrade the base box" \
  vagrant box update

if ! vagrant status --machine-readable 2>&1 | grep 'default,state,not_created' ; then
  log_step "Destroy the existing machine" \
    vagrant destroy -f
fi

log_step "Bring up the machine" \
  vagrant up \
    --no-provision \
    --provider="${VAGRANT_PROVIDER}"

log_step "Provision the machine" \
  vagrant provision

if [ -x "$VAGRANT_PROVIDER_SCRIPT" ] ; then
  log_stage "Executing provider setup script: $VAGRANT_PROVIDER_SCRIPT"

  log_step "Source the script" \
    source "$VAGRANT_PROVIDER_SCRIPT"

  log_step "Execute provider setup" \
    vagrant_provider_setup

  log_stage "Provider setup script finished!"
fi

log_stage "Begin packaging of machine ${VM_NAME}@${VAGRANT_PROVIDER} "

log_step "Stop the machine" \
  vagrant halt

rm -vf "${VAGRANT_BOX}.box"

log_step "Create the box file" \
  vagrant package \
    --output "${VAGRANT_BOX}.box" \
    --vagrantfile Vagrantfile.dist \
      "default"

log_step "Add local box" vagrant box add "${VAGRANT_BOX}.box" --name "${VAGRANT_CLOUD_BOX}" --force

if [ -n "${ATLAS_TOKEN:-""}" ] && [ "${TRAVIS_PULL_REQUEST:-""}" != "true" ];then
  log_step "Vagrant cloud auth" vagrant cloud auth whoami

  log_stage "Publishing Box release to Vagrant cloud: ${VAGRANT_CLOUD_BOX}#${VAGRANT_CLOUD_BOX_VERSION}"

  log_step "Publish and release the package" \
    vagrant cloud publish \
      --force \
      --release \
      --description "${VAGRANT_CLOUD_BOX_DESCRIPTION:-'N/A'}" \
      --version-description "${VAGRANT_CLOUD_BOX_VERSION_DESCRIPTION:-Automated Build}" \
        "${VAGRANT_CLOUD_BOX}" \
        "${VAGRANT_CLOUD_BOX_VERSION}" \
        "${VAGRANT_PROVIDER}" \
        "${VAGRANT_BOX}.box"
else
  log_step "ATLAS_TOKEN is not set or this is pull request skipping box publishing"
fi

log_step "Leave vagrant directory" \
  popd >/dev/null

log_stage "Machine ${VM_NAME}@${VAGRANT_PROVIDER} for box ${VAGRANT_BOX} is ready!"
