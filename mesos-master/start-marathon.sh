#!/bin/bash

if [ $# != 1 ]; then
    echo "$0 mesos-master-ip"
    exit 1
fi


ip=$1
MESOS_NATIVE_JAVA_LIBRARY=/usr/local/mesos/lib/libmesos.so ./bin/start --master zk://$ip:2181/mesos --zk zk://$ip:2181/marathon >> /var/log/marathon.log 2>&1 &
