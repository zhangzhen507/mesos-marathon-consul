#!/bin/bash

if [ $# != 3 ]; then
    echo "$0 host port json"
    exit 1
fi


boot-service()
{
	host=$1
	port=$2
	json=$3

	curl -X POST http://${host}:${port}/v2/apps -d @${json} -H "Content-type: application/json"
}

boot-service $1 $2 $3
