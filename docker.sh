#! /usr/bin/bash
# System: centos 7
# Author: minskiter
# Date: 2020-07-13

DATA_ROOT="/home/docker"
DRIVER="systemd"
QUITE=0
REMOTE_HOST="0.0.0.0:2375"
AUTHOR="minskiter"

# Usage
usage(){
cat << USAGE >&2
DOCKER-INSTALL SCRIPT
AUTHOR: $AUTHOR
Usage: 
    $0 [options] 

Options:
    -d dir | --data-dir               data-root for docker;default: /home/docker
    -dv driver | --driver             cgroupfs | systemd(default)
    -q | --quite                      Don't output any message
    -r remote api | --remote-api      Remote Api Host 0.0.0.0:2375(default)

For more details see $AUTHOR.github.io
USAGE
exit 1
}

install(){
sudo yum update
# Remove Older Docker Ce
if [[ $QUITE -eq 0 ]]; then
    echo "[$(date)] Remove Old Docker CE"
fi
sudo yum remove docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine -y
if [[ $QUITE -eq 0 ]]; then
    echo "[$(date)] Install New Docker CE"
fi
# Install Docker CE
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install docker-ce docker-ce-cli containerd.io -y
}

configure(){
if [[ $QUITE -eq 0 ]]; then
    echo "[$(date)] Configure Docker Deamon"
fi
sudo cat << CONFIGURE > /etc/docker/daemon.json
{
    "data-root": "$DATA_ROOT",
    "registry-mirrors": [
        "https://docker.mirrors.ustc.edu.cn"
    ],
    "exec-opts": [
        "native.cgroupdriver=$DRIVER"
    ]
}
CONFIGURE
TEXT="$(cat /lib/systemd/system/docker.service)"
START="$(echo $(cat << DOCKER_SERVICE | grep ExecStart | grep -v ${REMOTE_HOST}
${TEXT}
DOCKER_SERVICE
))"
if [ "$START" != "" ]; then
TEXT="$(sed "s|${START}|${START} -H tcp://${REMOTE_HOST}|g" <<< "${TEXT}")"
cat << REPLACE > /lib/systemd/system/docker.service
${TEXT}
REPLACE
fi
} 

start(){
if [[ $QUITE -eq 0 ]]; then
    echo "[$(date)] Start Docker..."
fi
systemctl start docker
systemctl enable docker
}

reload(){
if [[ $QUITE -eq 0 ]]; then
    echo "[$(date)] Reload Docker..."
fi
systemctl daemon-reload
systemctl restart docker
}

while [[ $# -gt 0 ]]
do
    case "$1" in
        -d )
        DATA_ROOT="$2"
        shift 2
        ;;
        --data-dir=* )
        DATA_ROOT="${1#*=}"
        shift 1
        ;;
        -dv )
        DRIVER="$2"
        shift 2
        ;;
        --driver=* )
        DRIVER="${1#*=}"
        shift 1
        ;;
        -q )
        QUITE=1
        shift 1
        ;;
        --quite=* )
        QUITE="${1#*=}"
        shift 1
        ;;
        -r )
        REMOTE_HOST="$2"
        shift 2
        ;;
        --remote-api=* )
        REMOTE_HOST="${1#*=}"
        shift 1
        ;;
        * )
        echo "[$(date)] Unknow argument: $1">&2
        usage
        ;;
    esac
done

install 
start
configure
reload



