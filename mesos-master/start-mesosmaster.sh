#!/bin/bash

if [ $# != 1 ]; then
    echo "$0 mesos-master-ip"
    exit 1
fi


ip=$1
./sbin/mesos-master --ip=$ip --work_dir=/var/lib/mesos/master --log_dir=/var/log/mesos --zk=zk://$ip:2181/mesos --quorum=1 >> /dev/null 2>&1 &
