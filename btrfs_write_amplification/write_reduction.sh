#!/bin/bash

dev=$1
bs=$2
rw=$3
sze=$4
njob=$5
depth=$6
kernel=$7
size=$8
io_size=$9
run=${10}

#usage
#./write_reduction.sh [device] [bs] [rw] [filesize] [njobs] [depth] [btrfs_kernel_loadable_module_path] [size] [io_size] [run]

if [[ $# -ne 10 ]]; then
    echo "Illegal number of parameters"
    exit 2
fi

DIR=$(date +"%H-%M-%S-%d-%m-%y")
mkdir $DIR

compute()
{
        mo=$1 #mount option
        it=$2 #iteration
        ot=${mo}_${bs}_${rw}_${njob}_${depth}_${it}

	dmesg -C

        if [ ${mo} == "nodatasum" ]; then
                nvme format ${dev} -l 1 -i 0 -f
        else
                nvme format ${dev} -l 0 -f
        fi

        mkfs.btrfs -f ${dev} > $DIR/mkfs_${ot}

        rmmod btrfs
        insmod $kernel
	cat /sys/fs/btrfs/features/tree_writes > $DIR/writes_before

        if [ ${mo} == "nodatasum" ]; then
                mount -t btrfs ${dev} /mnt -o nodatasum
        else
                mount -t btrfs ${dev} /mnt
        fi

        iostat -k -d ${dev} > $DIR/x1
        awk 'NR>=4 {print $7}' $DIR/x1 > $DIR/y1
        head -n -2 $DIR/y1 > $DIR/z1
        org_writes=$(cat $DIR/z1)
        echo "writes before running fio" $org_writes

        #iteration 1 write to whole device
        echo "fio --name=btrfswrite_a --ioengine=io_uring --directory=/mnt --blocksize=${bs} --readwrite=${rw} --filesize=${sze}G --size=${size}G --io_size=${io_size}G --numjobs=${njob} --iodepth=${depth} --randseed=1 --direct=1 -output=$DIR/fio_out_${ot}_a --group_reporting" > $DIR/fio_command_${ot}_a
        fio --name=btrfswrite_a --ioengine=io_uring --directory=/mnt --blocksize=${bs} --readwrite=${rw} --filesize=${sze}G --size=${size}G --io_size=${io_size}G --numjobs=${njob} --iodepth=${depth} --randseed=1 --direct=1 -output=$DIR/fio_out_${ot}_a --group_reporting

        umount /mnt
	cat /sys/fs/btrfs/features/tree_writes > $DIR/writes_after
        rmmod btrfs
        dmesg > $DIR/dmesg_${ot}
        dmesg -C

        iostat -k -d ${dev} > $DIR/x2
        awk 'NR>=4 {print $7}' $DIR/x2 > $DIR/y2
        head -n -2 $DIR/y2 > $DIR/z2
        btrfs_writes=$(cat $DIR/z2)
        echo "writes after running fio" $btrfs_writes

        total_writes_on_device=$((btrfs_writes-org_writes))
        div=$((1024*1024))
        printf -v twgb "%f\n" $((10**6 * total_writes_on_device/div))e-6
        total_writes_by_application=$((size*1024*1024*njob))
        ew=$((total_writes_on_device-total_writes_by_application))
        printf -v ewgb "%f\n" $((10**6 * ew/div))e-6
        tot_write=$((size*njob))
        echo "total writes in kb/gb with $mo" $total_writes_on_device $twgb
        echo "extra writes in kb/gb with $mo" $ew $ewgb
        echo "${total_writes_on_device} / ${twgb} / ${ew} / ${ewgb}"  >> $DIR/output_${ot}

        insmod $kernel
}

echo $DIR created

if [ ${run} == "nodatasum" ]; then
	echo "running nodatasum"
	compute nodatasum 1
else
	echo "running base"
	compute base 1
fi
