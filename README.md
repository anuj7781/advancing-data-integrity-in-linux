# Advancing Data Integrity in Linux — Artifact Repository (USENIX FAST 2026)

This repository contains the artifacts for the paper **“Advancing Data Integrity in Linux”** published at **USENIX FAST 2026**.  
Paper page: https://www.usenix.org/conference/fast26/presentation/gupta

## Repository contents

### Kernel branches (FS-PI enabled)
Use the following kernel branches to reproduce the results:

- **btrfs-pi kernel**: https://github.com/SamsungDS/linux/tree/feat/pi/fast/btrfs_v1  
- **xfs-pi kernel**: https://github.com/SamsungDS/linux/tree/feat/pi/fast/xfs_v1

### Benchmarks / scripts
- `btrfs_write_amplification/` - Btrfs buffered/direct-I/O write amplification
- `btrfs_cpu_util/` - Btrfs direct-I/O CPU utilization
- `btrfs_perf/` - Btrfs buffered/direct-I/O performance
- `xfs_perf/` - XFS buffered/direct-I/O performance

Each subfolder contains a dedicated `README.md` with usage, parameters, and expected outputs.

## Tested environment (recommended)
- OS: Ubuntu (tested on: 24.04.3 LTS)
- Storage: NVMe SSD with PI support

## Build & install the artifact kernel

### 1) Clone and checkout the artifact branch
```bash
git clone https://github.com/SamsungDS/linux.git
cd linux

# Choose ONE:
git checkout feat/pi/fast/btrfs_v1
# OR
git checkout feat/pi/fast/xfs_v1
```

### 2) Install build dependencies
```bash
sudo apt-get update
sudo apt-get install -y \
  git build-essential fakeroot libncurses5-dev libssl-dev ccache \
  bison flex libelf-dev dwarves zstd
```

### 3) Configure, build, and install
Start from your currently running kernel config
```bash
cp /boot/config-$(uname -r) .config
```

Update config to match this tree
```bash
make olddefconfig
```
Build
```bash
make -j"$(getconf _NPROCESSORS_ONLN)"
```
Install modules + kernel
```bash
sudo make modules_install
sudo make install
```
Install headers (optional; useful for tooling)
```bash
sudo make headers_install INSTALL_HDR_PATH=/usr
```
### 4) Reboot and select the installed kernel
```bash
sudo reboot
```
### 5) Verify the running kernel
```bash
uname -r
```
