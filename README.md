# MageOps Vagrant Boxes

[![Travis Build](https://travis-ci.com/mageops/vagrant-box-build.svg?branch=master&status=created)](https://travis-ci.com/mageops/vagrant-box-build)

_This repository contains the sources that are used to automatically build,
update and publish Vagrant base boxes for local development purposes._

**If you're curious what it's all about then start with the `mageops/magesuite` box.**

## Boxes

**All of the boxes are published to [MageOps at Vagrant Cloud](https://app.vagrantup.com/mageops)!**

The boxes are made for the [VirtualBox]()<sup>1</sup> provider as it's the most easy, supported
and widely-used one.

Thanks to [Vagrant](https://www.vagrantup.com/intro/index.html) getting started is as easy as two commands:

```sh
vagrant init mageops/centos
vagrant up
```

> <sup>1</sup> It's not tested yet, but all VirtualBox boxes store the machines in
> _OVF_ format and thus should work in VMWare by extension.

### 📦 `mageops/centos` - optimized _CentOS 7_

_**Performance-boosted CentOS 7 system extending the [official box](https://app.vagrantup.com/centos/boxes/7).**_

#### 🚀 **Improvements in relation to the the original box**

 - Up-to-date packages<sup>1</sup>
 - Common CLI tools preinstalled
 - Disk resized to 100GB
 - Swap partition on a dedicated *fixed sized* writethrough disk
 - **Storage controller upgraded to SCSI (from IDE) for a huge ⚡️ IO boost<sup>2</sup>**
 - All disks have host caching, discard, and SSD emulation enabled by default<sup>3</sup>
 - Faster boot - boot only from disk, other options disabled
 - Paravirtualized Network (`virtio-net`) devices for better network performance
 - Kernel upgrade: stable mainline kernel (5.6 branch)
 - IO scheduler changed to `deadline-mq` which better fits the expected workload
 - [All CPU Bug mitigations off in the guest](https://make-linux-fast-again.com)
 - VirtualBox VM performance-enhacing features enabled (e.g. speculation control)
 - Memory usage optimization via `zswap` (default conservative settings)
 - Audio support disabled as it causes many problems on macOS

_These choices are based on comparison benchmarking<sup>4</sup>, expertise and experience._

> <sup>1</sup> Box is rebuilt automatically periodically with `yum update` each time.
>
> <sup>2</sup> Benchmarked up to 2GB/s IO speed in comparison to 80MB/s locked rate with IDE.
>
> <sup>3</sup> As 99% of today's workstations use SDD/NVMe drives this settings
> should extend the life of your machine's drive (TRIM), improve performance and possibly
> enable better compaction of the virtual disk images _(not sure about VBox support)_.
>
> <sup>4</sup> All testing has been done on macOS host as this is what we primarily
> use at [creativestyle](https://creativestyle.pl) for developer workstations.

#### 🗓 Still a few things left todo
 - Install Guest Additions for latest VirtualBox version on build
   * _[Optionally]_ Attach Guest Additions DVD on boot using dist Vagrantfile
   * _[Optionally]_ Install a systemd service that updates Guest Addtions on boot
 - Improve NFS share performance
   * **Note: It might even work better than unison if set up properly on host and guest**
     - Recently many articles appeared that are reporting superb NFS file
       sharing performance although it depends on configuration details
       and possibly requires latest software.
   * Check if NFS over UDP improves perf
   * Check if NFSv4 is better or worse
   * Set up CacheFS with performance-optimized settings on guest
     - Many improvements and possibilities thanks to newer kernel
   * Ensure proper macOS host settings (see what Vagrant does OOTH)
     - macOS export should have `mapall` directive that squashes the owner to
       the logged in user's UID/GID (501:20 by default)
     - `noresvport` option might be needed
     - check `nfs.conf` settings (enable `nfs.server.async`?)
   * Make sure NFS locking (`nfslockd`) communication is set up and working
     properly so we can avoid many strange problems
   * Squash owner to `magento` user on guest

### 📦 `mageops/raccoon` - Packaged Magento Development Environment

**🚧 Work in progress - not yet available, stay tuned.**

_Built on top of `mageops/centos`._

This box is automatically provisioned with [MageOps Ansible Infrastructure](https://github.com/ansible-infrastructure)
to provide all software needed to run Magento locally in a state-of-the-art setup
resembling our production architecture as closely as possibly while providing
many conveniences suited for local development.


#### Provisioning Notes

> Note: We could use the Ansible Vagrant provisioner but it actually cannot
> handle our custom MageOps setup and it really doesn't provide any tangible
> benefit in this case. Better to use a shell provisioner with a simple script
> that bootstraps the Ansible env and runs the playbook...

0. Set up global MAGEOPS_ environment variables via system profile.
   So provisioning/raccoon can detect it's running in Vagrant/VBox VM and
   act accordingly (skip local key authorization, etc.)
   * `MAGEOPS_ENV_TYPE=vagrant`
   * `MAGEOPS_ENV_PLATFORM=virtualbox`
1. clone ansible infrastructure to /opt/mageops/ansible
2. clone vagrant/raccon vars into /opt/mageops/ansilbe/vars/project
3. set up inventory that has vagrant as localhost with `ansible_connection=local`
4. install python3 and python3-virtualenv
5. create virtualenv in /opt/mageops/ansible/virtualenv
6. [in venv] install python reqs `pip install -r requirements-python.txt`
7. [in venv] install ansible reqs `ansible-galaxy install -r requirements-galaxy.yml -p roles`
8. [in venv] run vagrant provisioning playbook
10. ...
99. ... profit!!!

> Idea: Run raccoon PHP CLI inside the VM...

### 📦 `mageops/magesuite` - Preinstalled Demo Magento Shop with [MageSuite](https://magesuite.io)

**🚧 Work in progress - not yet available, stay tuned.**

_Built on top of `mageops/raccoon`._

The [Raccoon](https://github.com/mageops/raccoon) box with a demo shop installed and configured. Use it to check out
[MageSuite](https://github.com/magesuite) or just kickstart your development environment.


#### Provisioning notes

1. set up auth.json for repo.magento.com
2. composer create-project --repository-url=https://repo.magento.com/ magento/project-community-edition:2.3.4
3. composer require creativestyle/magesuite
4. run ansible provisioning for magento configuration with sample data installation
9. remove auth.json !!!
10. remove composer cache
99. test - do a few curls from host to make sure the shop is up and working