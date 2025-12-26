# Btrfs write amplification (FS-PI) — Artifact scripts

This directory contains the scripts used to collect the Btrfs write amplification data reported in the paper.

## Folder structure

- `buffered-io/`
  - `write_reduction.sh` — write amplification script for buffered I/O
- `direct-io/`
  - `write_reduction.sh` — write amplification script for direct I/O

Both scripts follow the same interface but correspond to different I/O types.

## IMPORTANT (FS-PI / btrfs-pi mode)
The **FS-PI (btrfs-pi) evaluation corresponds to the `nodatasum` run mode** in this script.
In this mode, Btrfs is mounted with `-o nodatasum` and the NVMe namespace is formatted with an LBA format that includes metadata (e.g., **4K + 64B** on our drive).

## WARNING: DATA LOSS
`write_reduction.sh` **formats** the target NVMe device (`nvme format`) and recreates the filesystem (`mkfs.btrfs -f`).
It will **destroy all data** on the specified device. Use a dedicated test SSD/namespace.

## Kernel requirement
Use the artifact kernel branch:
- https://github.com/SamsungDS/linux/tree/feat/pi/fast/btrfs_v1

The scripts expect a path to the Btrfs kernel module (`btrfs.ko`) built from this kernel tree.

## Dependencies
- `nvme-cli` (for `nvme format`)
- `btrfs-progs` (for `mkfs.btrfs`)
- `sysstat` (for `iostat`)
- `fio`

## Notes on tree-wise write counters (in-kernel instrumentation)
The script captures:
- `writes_before`: value of `/sys/fs/btrfs/features/tree_writes` before the fio run
- `writes_after`: value of `/sys/fs/btrfs/features/tree_writes` after the fio run

These values provide **tree-wise write counts** from our in-kernel counters.  
The script performs `rmmod btrfs` before the run to reset these in-kernel counters (module reload resets the counters), and `insmod` again before collecting/capturing.

## NVMe format (drive-specific)
The `nvme format` commands used in the script are **drive-specific** and depend on which LBA formats your NVMe device advertises.

On our drive:
- `base` corresponds to **4K + 0B metadata**
- `nodatasum` corresponds to **4K + 64B metadata** (FS-PI / btrfs-pi case)

If your device advertises different LBA formats, you must adjust the `nvme format` arguments (`-l`, `-i`, etc.) accordingly. Use `nvme id-ns` / `nvme id-ctrl` to inspect supported formats for your device.

---

## Parameters

device: NVMe namespace/block device (example: /dev/nvme0n1)

bs: block size (example: 4k)

rw: fio pattern (example: randwrite)

filesize: fio --filesize in GiB (script appends G)

njobs: fio --numjobs

depth: fio --iodepth

btrfs_kernel_module_path: path to btrfs.ko

size: fio --size in GiB (script appends G)

io_size: fio --io_size in GiB (script appends G)

run: either base or nodatasum

nodatasum mounts Btrfs with -o nodatasum and uses a different NVMe LBA format than base (see NVMe format note above).

---

## Example command (used for the paper)

sudo ./write_reduction.sh /dev/nvme0n1 4k randwrite 10 24 128 /home/test/gost/anuj/linux/fs/btrfs/btrfs.ko 10 10 base

---

## Outputs

The script creates an output directory named with the current timestamp (e.g. HH-MM-SS-dd-mm-yy/) containing:

mkfs_* — mkfs output

fio_out_* — fio output

fio_command_* — fio command line recorded by the script

dmesg_* — kernel logs captured after the run

writes_before — tree-wise write counters before fio (from /sys/fs/btrfs/features/tree_writes)

writes_after — tree-wise write counters after fio (from /sys/fs/btrfs/features/tree_writes)

output_* — summary line: <total device writes> \/ <GiB> \/ <extra writes> \/ <extra GiB>
