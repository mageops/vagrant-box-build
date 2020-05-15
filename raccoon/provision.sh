
yum -y install \
    python3 \
    python3-virtualenv \
    python3-pip

mkdir -p /opt/mageops

pushd /opt/mageops

git clone \
    --branch develop \
        https://github.com/mageops/ansible-infrastructure.git \
        ansible

virtualenv-3 virtualenv

pushd ansible

mkdir -p \
    vars/project \
    vars/global

pip install \
    -r requirements-python.txt

ansible-galaxy install \
    -r requirements-galaxy.yml \
    -p roles \
    --force

VAGRANT_ASSETS_DIR="$(pwd)/assets/vagrant"

mkdir -p "$VAGRANT_ASSETS_DIR/"{files,templates,tasks,certs}

ansible-playbook \
    -i inventory/vagrant-nested.ini vagrant.yml \
    -e "mageops_project_assets_dir=$PROJECT_ASSETS_DIR" \
    -e "mageops_ansible_provisioning_mode=local_nested" \
        vagrant.yml