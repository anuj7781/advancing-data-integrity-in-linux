# Btrfs CPU utilization (direct I/O) — Artifact scripts

This directory contains the scripts used to collect CPU utilization numbers for **Btrfs direct I/O** reported in the paper.

## Folder structure

- `write_reduction.sh`
  - Used for **direct I/O** `randwrite` and `seqwrite` CPU utilization.
  - Formats + mkfs the device, mounts, runs fio, and records CPU utilization via `sar`.
- `read.sh`
  - Used for **direct I/O** `randread` and `seqread` CPU utilization.
  - **Does NOT format or mkfs**. It mounts an existing Btrfs filesystem on the device and runs the read workload while collecting CPU utilization via `sar`.

## IMPORTANT (FS-PI / btrfs-pi mode)

The **FS-PI (btrfs-pi) evaluation corresponds to the `nodatasum` run mode** in these scripts.
In this mode, Btrfs is mounted with `-o nodatasum` and the NVMe namespace is formatted with an LBA format that includes metadata (e.g., **4K + 64B** on our drive).

## IMPORTANT (IOPS rate limiting for fair CPU-util comparison)

FS-PI (`nodatasum`) can achieve **higher IOPS than base**. To compare CPU utilization fairly at the **same throughput**, fio supports the `--rate_iops` option.

For FS-PI runs, we **rate-limit IOPS to match the base case** (the exact rate depends on the base run result on your setup). In the scripts, an example `--rate_iops` line is present (commented); users should enable/adjust it as needed.

## WARNING: DATA LOSS

- `write_reduction.sh` **formats** the target NVMe device (`nvme format`) and recreates the filesystem (`mkfs.btrfs -f`). It will **destroy all data** on the specified device.
- `read.sh` does **not** format/mkfs, but it assumes the device already contains a valid Btrfs filesystem and will mount it.

Use a dedicated test SSD/namespace.

## Kernel requirement

Use the artifact kernel branch:
- https://github.com/SamsungDS/linux/tree/feat/pi/fast/btrfs_v1

## Dependencies

- `nvme-cli` (used by `write_reduction.sh`)
- `btrfs-progs` (used by `write_reduction.sh` for `mkfs.btrfs`)
- `sysstat` (`sar`, `iostat`)
- `fio`
- `jq` (scripts parse fio JSON output)

## NVMe format (drive-specific)

The `nvme format` commands used in `write_reduction.sh` are **drive-specific** and depend on which LBA formats your NVMe device advertises.

On our drive:
- `base` corresponds to **4K + 0B metadata**
- `nodatasum` corresponds to **4K + 64B metadata** (FS-PI / btrfs-pi case)

If your device advertises different LBA formats, you must adjust the `nvme format` arguments accordingly. Use `nvme id-ns` / `nvme id-ctrl` to inspect supported formats for your device.

---

## Parameters

device: NVMe namespace/block device (example: /dev/nvme0n1)

bs: block size (example: 4k)

rw: fio pattern (example: randwrite / seqwrite / randread / seqread)

filesize: fio --filesize in GiB (script appends G)

njobs: fio --numjobs

depth: fio --iodepth

size: fio --size in GiB (script appends G)

io_size: fio --io_size in GiB (script appends G)

run: either base or nodatasum

nodatasum mounts Btrfs with -o nodatasum and uses a different NVMe LBA format than base (see NVMe format note above).

---

## `--rate_iops` usage (for FS-PI fairness)

To compare CPU utilization at the same throughput:
1) Run `base` once and note the achieved IOPS.
2) Re-run `nodatasum` with `--rate_iops` set to the base-case IOPS (or a per-job equivalent, depending on how you apply rate limiting).

Example (as used in the script comments):
- `--rate_iops=,3128`
- `--rate_iops=4220`

Adjust this value based on your base-case result and matching methodology.

---

## Example commands

### Write CPU-util (direct I/O) — randwrite/seqwrite
Base run
```bash
sudo ./write_reduction.sh /dev/nvme0n1 4k randwrite 10 24 128 10 10 base
```
FS-PI run (optionally enable --rate_iops inside the script):
```bash
sudo ./write_reduction.sh /dev/nvme0n1 4k randwrite 10 24 128 10 10 nodatasum
```

### Read CPU-util (direct I/O) — randread/seqread
Prerequisite: the device must already contain a Btrfs filesystem populated with files (commonly created by running the write_reduction.sh workload first).
Base run
```bash
sudo ./read.sh /dev/nvme0n1 4k randread 10 24 128 10 10 base
```
FS-PI run (optionally enable --rate_iops inside the script):
```bash
sudo ./read.sh /dev/nvme0n1 4k randread 10 24 128 10 10 nodatasum
```

## Outputs

Both scripts create an output directory named with the current timestamp (e.g. HH-MM-SS-dd-mm-yy/) containing:

fio_command_* — fio command line recorded by the script

`<ot>` — fio JSON output file (because --output-format=json is used)

sar_`<ot>`.out — raw sar output

summary_`<ot>`, final_`<ot`>, avg_`<ot`> — intermediate + average CPU utilization derived from sar

dmesg_`<ot>` — kernel logs captured after the run

output_`<ot>` — summary line: `<total device writes>` / `<GiB>` / `<extra writes>` / `<extra GiB>`

Additional files produced by write_reduction.sh only:

mkfs_* — mkfs output
