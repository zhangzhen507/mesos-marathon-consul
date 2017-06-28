# mesos-marathon-consul
This is an micro-service platform using mesos marathon consul 

主机信息：
IP                hostname      role             software  
192.168.1.64    mesosmaster  (mesos-master)    docker, zookeeper, mesos, marathon, consul
192.168.1.61    ubuntu       (mesos-slave)     docker, mesos, consul
192.168.1.74    mesosslave2  (mesos-slave)     docker, mesos, consul

1. 启动zookeeper
解压zookeeper-3.4.8到 /usr/local/配置conf/zoo.cfg

# The number of milliseconds of each tick
tickTime=2000
# The number of ticks that the initial
# synchronization phase can take
initLimit=10
# The number of ticks that can pass between
# sending a request and getting an acknowledgement
syncLimit=5
# the directory where the snapshot is stored.
# do not use /tmp for storage, /tmp here is just
# example sakes.
dataDir=/var/lib/zookeeper
# the port at which the clients will connect
clientPort=2181
# the maximum number of client connections.
# increase this if you need to handle more clients
#maxClientCnxns=60
#
# Be sure to read the maintenance section of the
# administrator guide before turning on autopurge.
#
# http://zookeeper.apache.org/doc/current/zookeeperAdmin.html#sc_maintenance
#
# The number of snapshots to retain in dataDir
#autopurge.snapRetainCount=3
# Purge task interval in hours
# Set to "0" to disable auto purge feature
#autopurge.purgeInterval=1

启动zookeeper:
# ./bin/zkServer.sh start

检查2181端口 
# netstat -nltp | grep 2181

2. 启动mesos cluster
在mesos-master结点启动 start-mesosmaster.sh
# netstat -ntlp | grep 5050
tcp        0      0 192.168.1.64:5050     0.0.0.0:*               LISTEN      3048/mesos-master

在mesos-slave结点依次启动 start-mesosslave.sh
# netstat -ntlp | grep 5051
tcp        0      0 0.0.0.0:5051            0.0.0.0:*               LISTEN      3036/mesos-agent


3. 启动marathon
解压marathon-1.3.9到 /usr/local
在mesos-master结点运行 start-marathon.sh


运行一个app 在marathon上
ip=192.168.1.64
json=marathon-lb.json
curl -X POST http://${ip}:8080/v2/apps -d @${json} -H "Content-type: application/json"

4. 安装consul在所有节点
We will use consul for service discovery and as our primary DNS for nodes and docker containers. When you install consul on all nodes of your cluster, please make sure you install consul in server mode on master nodes and in client mode on slave nodes. if we happen to add a new client node in future, consul will also be installed on that node in client mode. Also install consul UI on all nodes of cluster.

下载consul的可执行程序到 /usr/bin/consul
把consul_server.sh 放到 /usr/bin/consul_server.sh
把consul_client.sh 放到 /usr/bin/consul_client.sh

运行 consul_server.sh mesos-master-ip 启动 consul-server
运行 consul_client.sh mesos-slave-ip  启动 consul-client

# netstat -ntlp | grep consul
tcp        0      0 192.168.1.64:8300     0.0.0.0:*               LISTEN      3353/consul
tcp        0      0 192.168.1.64:8301     0.0.0.0:*               LISTEN      3353/consul
tcp        0      0 192.168.1.64:8302     0.0.0.0:*               LISTEN      3353/consul
tcp6       0      0 :::8500                 :::*                    LISTEN      3353/consul
tcp6       0      0 :::8600                 :::*                    LISTEN      3353/consul

# netstat -ntlp | grep consul
tcp        0      0 192.168.1.74:8301     0.0.0.0:*               LISTEN      3138/consul
tcp6       0      0 :::8500                 :::*                    LISTEN      3138/consul
tcp6       0      0 :::8600                 :::*                    LISTEN      3138/consul

打开consul界面查看服务和结点信息
http://192.168.1.64:8500/ui

Register Zookeeper and Marathon running on Master nodes with Consul
在 /etc/consul.d/bootstrap目录下有marathon.json, zookeeper.json的服务配置文件
在 mesos-master节点上 /etc/consul.d/bootstrap 下有config.json配置consul-server的信息
在 mesos-slave 节点上 /etc/consul.d/client 下有config.json配置consul-client的信息

查看consul集群信息
# consul members
Node         Address              Status  Type    Build  Protocol  DC
mesosmaster  192.168.1.64:8301  alive   server  0.8.3  2         local-cloud
mesosslave2  192.168.1.74:8301  alive   client  0.8.3  2         local-cloud
ubuntu       192.168.1.61:8301  alive   client  0.8.3  2         local-cloud

5. 在所有节点上安装dnsmasq
echo "server=/consul/127.0.0.1#8600" | sudo tee /etc/dnsmasq.d/10-consul
sudo /etc/init.d/dnsmasq restart

Once dnsmasq is restarted, all DNS queries will go to consul first. In order to test it quickly run "nslookup consul.service.consul" and you should see the results coming back. You will realize the importance of this in few minutes.

Run the following commands on Master instances to register zookeeper and marathon as consul services. (You may have to change the commands a little bit based on your consul config directory location)

echo '{"service": {"name": "marathon", "tags": ["marathon"], "port": 8080, "check": {"script": "curl localhost:8080 >/dev/null 2>&1", "interval": "10s"}}}' | sudo tee /etc/consul.d/marathon.json

echo '{"service": {"name": "zookeeper", "tags": ["zookeeper"], "port": 2181}}' | sudo tee /etc/consul.d/zookeeper.json
Once zookeeper and marathon are registered with consul, try running nslookup zookeeper.service.consul and nslookup marathon.service.consul on any of the nodes. Impressive right?? Also in Consul UI, you should see something like this


6. 修改docker配置
Configure Consul as DNS Server for use by Docker containers on Slave Nodes
在所有mesos-slave节点上修改docker的配置
vi /etc/default/docker

DOCKER_OPTS="--dns 192.168.1.74 --dns-search service.consul"

DOCKER_OPTS="--dns 192.168.1.61 --dns-search service.consul"


# systemctl daemon-reload
# systemctl restart docker.service


7. Launch mesos-consul docker container using Marathon

Our second problem of application registration and de-registration will be solved by mesos-consul. mesos-consul is a Mesos to Consul bridge for service discovery. Mesos-consul automatically registers/deregisters services running as Mesos tasks. if you have a Mesos task called application, this program will register the application in Consul, and it will be exposed via DNS as application.service.consul.



# Save the following json as mesos-consul.json on any node of cluster
{
  "args": [
    "--zk=zk://zookeeper.service.consul:2181/mesos",
    "--log-level=debug",
    "--consul",
    "--refresh=5s"
  ],  
  "container": {
    "type": "DOCKER",
    "docker": {
      "network": "BRIDGE",
      "image": "ciscocloud/mesos-consul"
    }   
  },  
  "id": "mesos-consul",
  "instances": 1,
  "cpus": 0.1,
  "mem": 256 
}

Run this command to launch mesos-consul docker container

./boot-microservices.sh marathon.service.consul 8080 mesos-consul.json

# curl -X POST -d@mesos-consul.json -H "Content-Type: application/json" http://marathon.service.consul:8080/v2/apps

Once the submit the above command, check Marathon-UI, Mesos-UI and Consul-UI. Most interesting thing that you will observe will be 2 new services in Consul-UI called mesos and mesos-consul, both of them are registered in consul by mesos-consul docker container launched above.

Given the fact that mesos-consul docker container is able to communicate with zookeeper.service.consul (passed to container as an argument) proves that docker containers are able to use consul running on host machines as their DNS server. 

At this point try nslookup leader.mesos.service.consul, nslookup master.mesos.service.consul, nslookup agent.mesos.service.consul and nslookup mesos-consul.service.consul on any of the nodes and check the results.

Finally Its time to run our first application container :)

curl -X POST -H "Content-Type: application/json" marathon.service.consul:8080/v2/apps -d '
{
    "container": {
      "type": "DOCKER",
      "docker": {
        "image": "libmesos/ubuntu"
      }
    },
    "id": "mohit",
    "instances": 1,
    "cpus": 0.5,
    "mem": 128,
    "uris": [],
    "cmd": "while sleep 10; do date -u +%T; done"
}'

Once the submit the above command, check Marathon-UI, Mesos-UI and Consul-UI. You will notice that container is running, try scaling out, destroying the containers etc. via marathon. 

Again my favorite part, run nslookup mohit.service.consul

At this point, you have a production ready mesos cluster running, where docker containers are launched and managed by marathon. Any mesos task gets registered with consul for easier service discovery.