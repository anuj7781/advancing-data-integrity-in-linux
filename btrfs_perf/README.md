# Btrfs performance (KIOPS) — Artifact scripts

This directory contains the scripts used to measure Btrfs performance (reported as KIOPS) using `fio`.

## Folder structure

- `direct-io/`
  - `write_reduction.sh` — write workloads for direct I/O (creates filesystem + files)
  - `read.sh` — read workloads for direct I/O (assumes filesystem/files already exist)
- `buffered-io/`
  - `write_reduction.sh` — write workloads for buffered I/O (creates filesystem + files)
  - `read.sh` — read workloads for buffered I/O (assumes filesystem/files already exist)

## IMPORTANT (FS-PI / btrfs-pi mode)

The **FS-PI (btrfs-pi) evaluation corresponds to the `nodatasum` run mode** in these scripts.
In this mode, Btrfs is mounted with `-o nodatasum` and the NVMe namespace is formatted with an LBA format that includes metadata (e.g., **4K + 64B** on our drive).

## WARNING: DATA LOSS

`write_reduction.sh` **formats** the target NVMe device (`nvme format`) and recreates the filesystem (`mkfs.btrfs -f`).
It will **destroy all data** on the specified device. Use a dedicated test SSD/namespace.

`read.sh` does **not** create a filesystem and does **not** create files. It assumes the filesystem and files already exist (typically created by running `write_reduction.sh` first).

## Kernel requirement

Use the artifact kernel branch:
- https://github.com/SamsungDS/linux/tree/feat/pi/fast/btrfs_v1

## Dependencies

- `nvme-cli` (used by `write_reduction.sh`)
- `btrfs-progs` (used by `write_reduction.sh` for `mkfs.btrfs`)
- `sysstat` (`iostat`)
- `fio`

## NVMe format (drive-specific)

The `nvme format` commands used in `write_reduction.sh` are **drive-specific** and depend on which LBA formats your NVMe device advertises.

On our drive:
- `base` corresponds to **4K + 0B metadata**
- `nodatasum` corresponds to **4K + 64B metadata** (FS-PI / btrfs-pi case)

If your device advertises different LBA formats, you must adjust the `nvme format` arguments accordingly. Use `nvme id-ns` / `nvme id-ctrl` to inspect supported formats for your device.

---

## Parameters

1. device: NVMe namespace/block device (example: /dev/nvme0n1)

2. bs: block size (example: 4k)

3. rw: fio pattern (example: randwrite / write / randread / read)

4. filesize: fio --filesize in GiB (script appends G)

5. njobs: fio --numjobs

6. depth: fio --iodepth

7. size: fio --size in GiB (script appends G)

8. io_size: fio --io_size in GiB (script appends G)

9. run: either base or nodatasum

nodatasum mounts Btrfs with -o nodatasum and uses a different NVMe LBA format than base (see NVMe format note above).

---

## Workflow

### Step 1: Create filesystem and files (write phase)
Run `write_reduction.sh` first. This creates a fresh Btrfs filesystem and generates files via the write workload.

Example (direct I/O):
Base run
```bash
cd direct-io
sudo ./write_reduction.sh /dev/nvme0n1 4k randwrite 10 24 128 10 10 base
```
FS-PI run
```bash
sudo ./write_reduction.sh /dev/nvme0n1 4k randwrite 10 24 128 10 10 nodatasum
```
(Use buffered-io/ instead of direct-io/ for buffered I/O runs.)

### Step 2: Run read workload on existing filesystem/files (read phase)
Run read.sh after the write phase. read.sh mounts the existing filesystem and runs the read workload.
Example (direct I/O):
```bash
cd direct-io
sudo ./read.sh /dev/nvme0n1 4k randread 10 24 128 10 10 base
```
FS-PI run:
```bash
sudo ./read.sh /dev/nvme0n1 4k randread 10 24 128 10 10 nodatasum
```

### Collecting KIOPS
The scripts store the full fio output in fio_out_*.

### Outputs

Both scripts create an output directory named with the current timestamp (e.g. HH-MM-SS-dd-mm-yy/) containing:

mkfs_* — mkfs output (write phase only)

fio_out_* — fio output (contains IOPS/KIOPS)

fio_command_* — fio command line recorded by the script

dmesg_* — kernel logs captured after the run (write phase script captures dmesg)

output_* — summary line: `<total device writes>` / `<GiB>` / `<extra writes>` / `<extra GiB>`
