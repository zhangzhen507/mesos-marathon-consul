#!/bin/bash

if [ $# != 1 ]; then
    echo "$0 bind-ip"
    exit 1
fi


ip=$1
rm -rf /var/consul/*
consul agent -config-dir /etc/consul.d/client/ -bind=$ip -client=0.0.0.0 >> /var/log/consul.log 2>&1 &
