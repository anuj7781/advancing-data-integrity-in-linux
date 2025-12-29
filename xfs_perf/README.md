# XFS performance (KIOPS) — Artifact scripts

This directory contains the scripts used to measure XFS performance (reported as KIOPS) using `fio`.

## Folder structure

- `direct-io/`
  - `write_reduction.sh` — write workloads for direct I/O (creates filesystem + files)
  - `read.sh` — read workloads for direct I/O (assumes filesystem/files already exist)
- `buffered-io/`
  - `write_reduction.sh` — write workloads for buffered I/O (creates filesystem + files)
  - `read.sh` — read workloads for buffered I/O (assumes filesystem/files already exist)

## IMPORTANT (XFS-PI mode)
For XFS, the PI-enabled evaluation corresponds to the `withpi` run mode in these scripts.

## WARNING: DATA LOSS
`write_reduction.sh` **formats** the target NVMe device (`nvme format`) and recreates the filesystem (`mkfs.xfs -f`).
It will **destroy all data** on the specified device. Use a dedicated test SSD/namespace.

`read.sh` does **not** format/mkfs or create files. It assumes the filesystem and files already exist (typically created by running `write_reduction.sh` first).

## Kernel requirement
Use the artifact kernel branch:
- https://github.com/SamsungDS/linux/tree/feat/pi/fast/xfs_v1

## Dependencies
- `nvme-cli` (used by `write_reduction.sh`)
- `xfsprogs` (for `mkfs.xfs`)
- `sysstat` (`iostat`)
- `fio`

## NVMe format (drive-specific)
The `nvme format` commands used in `write_reduction.sh` are **drive-specific** and depend on which LBA formats your NVMe device advertises.

On our drive:
- `base` corresponds to **4K + 0B metadata**
- `withpi` corresponds to **4K + 64B metadata** (XFS-PI / PI-enabled case)

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

9. run: either base or withpi

---

## Workflow

### Step 1: Create filesystem and files (write phase)
Run `write_reduction.sh` first. This creates a fresh XFS filesystem and generates files via the write workload.

Example (direct I/O):
Base run
```bash
cd direct-io
sudo ./write_reduction.sh /dev/nvme0n1 4k randwrite 10 24 128 10 10 base
```
PI enabled run:
```bash
sudo ./write_reduction.sh /dev/nvme0n1 4k randwrite 10 24 128 10 10 withpi
```
(Use buffered-io/ instead of direct-io/ for buffered I/O runs.)

### Step 2: Run read workload on existing filesystem/files (read phase)
Run read.sh after the write phase. read.sh mounts the existing filesystem and runs the read workload.
```bash
cd direct-io
sudo ./read.sh /dev/nvme0n1 4k randread 10 24 128 10 10 base
```
PI-enabled run:
```bash
sudo ./read.sh /dev/nvme0n1 4k randread 10 24 128 10 10 withpi
```

## Collecting KIOPS
The scripts store the full fio output in fio_out_*.

## Outputs

Both scripts create an output directory named with the current timestamp (e.g. HH-MM-SS-dd-mm-yy/) containing:

mkfs_* — mkfs output (write phase only)

fio_out_* — fio output (contains IOPS/KIOPS)

fio_command_* — fio command line recorded by the script

dmesg_* — kernel logs captured after the run

output_* — summary line: `<total device writes>` / `<GiB>` / `<extra writes>` / `<extra GiB>`
