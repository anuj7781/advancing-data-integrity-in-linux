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
                nvme format ${dev} -l 1 -i 3 -f
        else
                nvme format ${dev} -l 0 -f
        fi

        echo "Doing mkfs now"
        mkfs.btrfs -f ${dev} > $DIR/mkfs_${ot}

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

        #run the sar command to collect the cpu-util stats
        sar -P ALL -o /tmp/sar_db_bench_cpu_${it} 1 99999 >/dev/null 2>&1 &

        #iteration 1 write to whole device
	#echo "fio --name=btrfswrite_a --ioengine=io_uring --directory=/mnt --blocksize=${bs} --readwrite=${rw} --filesize=${sze}G --size=${size}G --io_size=${io_size}G --numjobs=${njob} --iodepth=${depth} --randseed=1 --direct=1 --output-format=json -output=$DIR/${ot} --rate_iops=,3128 --group_reporting" > $DIR/fio_command_${ot}_a
        #fio --name=btrfswrite_a --ioengine=io_uring --directory=/mnt --blocksize=${bs} --readwrite=${rw} --filesize=${sze}G --size=${size}G --io_size=${io_size}G --numjobs=${njob} --iodepth=${depth} --randseed=1 --direct=1 --output-format=json -output=$DIR/${ot} --rate_iops=,3128 --group_reporting
        echo "fio --name=btrfswrite_a --ioengine=io_uring --directory=/mnt --blocksize=${bs} --readwrite=${rw} --filesize=${sze}G --size=${size}G --io_size=${io_size}G --numjobs=${njob} --iodepth=${depth} --randseed=1 --direct=1 --output-format=json -output=$DIR/${ot} --group_reporting" > $DIR/fio_command_${ot}_a
        fio --name=btrfswrite_a --ioengine=io_uring --directory=/mnt --blocksize=${bs} --readwrite=${rw} --filesize=${sze}G --size=${size}G --io_size=${io_size}G --numjobs=${njob} --iodepth=${depth} --randseed=1 --direct=1 --output-format=json -output=$DIR/${ot} --group_reporting

	#store output
        sar -f /tmp/sar_db_bench_cpu_${it} -P ALL > $DIR/sar_${ot}.out

        #kill sar
        pkill sar

        #compute
        var=$(jq '.time' $DIR/${ot} > $DIR/var)
        time=$(awk '{print $4}' $DIR/var)
        elapsed=$(jq '.jobs[0].elapsed' $DIR/${ot})
        #echo "time" ${time}
        #echo "elapsed" ${elapsed}

        grep "all" $DIR/sar_${ot}.out > $DIR/summary_${ot}

        a=0
        while [ $a -lt $elapsed ]
        do
                k=$(date -d "$(date -Iseconds -d "$time") + 0 hours - 0 minutes - ${a} seconds")
                echo ${k} > $DIR/i
                ct=$(awk '{print $4}' $DIR/i)
                #echo $a " " $ct
                grep $ct $DIR/summary_${ot} >> $DIR/final_${ot}
                ((a++))
        done
        tr -s ' ' < $DIR/final_${ot} | cut -d ' ' -f 9 | awk '{s+=$1}END{print "ave:",s/NR}' > $DIR/avg_${ot}

        umount /mnt
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
}

echo $DIR created

if [ ${run} == "nodatasum" ]; then
	echo "running nodatasum"
	compute nodatasum 1
else
	echo "running base"
	compute base 1
fi
