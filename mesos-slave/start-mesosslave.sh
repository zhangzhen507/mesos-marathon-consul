#!/bin/bash

if [ $# != 1 ]; then
    echo "$0 mesos-master-ip"
    exit 1
fi


ip=$1
./sbin/mesos-agent --master=$ip:5050 --work_dir=/var/lib/mesos/agent --log_dir=/var/log/mesos --containerizers='docker,mesos' >> /dev/null 2>&1 &
