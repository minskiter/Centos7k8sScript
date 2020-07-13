#! /usr/bin/bash
# System: centos 7
# Author: minskiter
# Date: 2020-07-13

PROXY=
REGISTRY=
CID="10.244.0.0/16"

usage(){
cat << USAGE >&2
K8S-INSTALL-MASTER SCRIPT
AUTHOR: $AUTHOR
Usage: 
    $0 [options] 

Options:
    -p | --proxy        http proxy for docker and k8s
    -r | --registry     k8sadm install mirror registry
    -h | --hostname     master hostname
    -cid | --pod-cidr   pod-network-cidr,10.244.0.0/16(default)

For more details see $AUTHOR.github.io
USAGE
exit 1
}

cancelSwap(){
echo "[$(date)] Swap off"
SWAP="$(sudo cat /etc/fstab | grep swap | grep -v '#')"
LENGTH=$(($(echo ${SWAP} | awk '{print length($0)}')))
if [[ $LENGTH -gt 4 ]]; then
# ignore swap
sudo sed -i "s|${SWAP}|#${SWAP}|g" /etc/fstab
fi
sudo swapoff -a
}

openMasterFireWall(){
echo "[$(date)] FireWall Open Port"
sudo firewall-cmd --permanent --zone=public --add-port=6443/tcp
sudo firewall-cmd --permanent --zone=public --add-port=2379-2380/tcp
sudo firewall-cmd --permanent --zone=public --add-port=10250-10252/tcp
sudo firewall-cmd --permanent --zone=public --add-port=6443/udp
sudo firewall-cmd --permanent --zone=public --add-port=2379-2380/udp
sudo firewall-cmd --permanent --zone=public --add-port=10250-10252/udp
sudo firewall-cmd --reload
}

setProxy(){
if [ "$PROXY" != "" ];then
export http_proxy=$PROXY
# yum proxy
if [[ $(echo $(sudo cat /etc/yum.conf | grep proxy) | awk '{print length($0)}') -eq 0 ]]; then 
echo proxy=$PROXY >> /etc/yum.conf
fi
# docker proxy
sudo mkdir -p /etc/systemd/system/docker.service.d
cat << PROXY_SERVICE > /etc/systemd/system/docker.service.d/http-proxy.conf
[Service]
Environment="HTTP_PROXY=$PROXY"
PROXY_SERVICE
fi
sudo systemctl daemon-reload
sudo systemctl restart docker
}

unsetProxy(){
unset http_proxy
if [[ $(echo $(sudo cat /etc/yum.conf | grep proxy) | awk '{print length($0)}') -gt 0 ]]; then 
sudo sed -i "s|$(sudo cat /etc/yum.conf | grep proxy)| |g" /etc/yum.conf
fi
sudo rm -rf /etc/systemd/system/docker.service.d/http-proxy.conf
sudo systemctl daemon-reload
sudo systemctl restart docker
}

installk8s(){
echo "[$(date)] Install k8sadm"
sudo cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=http://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=http://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg http://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
sudo yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
sudo systemctl enable --now kubelet
}

setup(){
echo "[$(date)] k8sadm setup k8s"
mkdir $HOME/temp
if [ "$HOSTNAME" != "" ];then
sudo hostnamectl set-hostname $HOSTNAME
if [ "$(cat /etc/hosts | grep $HOSTNAME)" = "" ];then
echo 127.0.0.1 $HOSTNAME >> /etc/hosts
fi
fi
if [ "$REGISTRY" != "" ];then
sudo kubeadm init --pod-network-cidr=$CID --image-repository=$REGISTRY
else
sudo kubeadm init --pod-network-cidr=$CID | grep token >> $HOME/temp/token.txt
fi
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
}

calico(){
echo "[$(date)] k8s create calico"
mkdir -p $HOME/k8s/calico
curl https://docs.projectcalico.org/manifests/tigera-operator.yaml -o $HOME/k8s/calico/tigera-operator.yaml
cat << IMAGE_LIST > $HOME/k8s/calico/images.list.txt
$(cat $HOME/k8s/calico/tigera-operator.yaml | grep image: | awk '{print $2}')
IMAGE_LIST
curl https://docs.projectcalico.org/manifests/custom-resources.yaml -o $HOME/k8s/calico/custom-resources.yaml
cat << IMAGE_LIST2 >> $HOME/k8s/calico/images.list.txt
$(cat $HOME/k8s/calico/custom-resources.yaml | grep image: | awk '{print $2}')
IMAGE_LIST2
sed -i "s|$(cat $HOME/k8s/calico/custom-resources.yaml | grep cidr | awk '{print $2}')|$CID|g" $HOME/k8s/calico/custom-resources.yaml
# TODO: change mirror registry
docker pull $(cat $HOME/k8s/calico/images.list.txt)
kubectl create -f $HOME/k8s/calico/tigera-operator.yaml
kubectl create -f $HOME/k8s/calico/custom-resources.yaml
}

while [[ $# -gt 0 ]]
do
    case "$1" in
        -p )
        PROXY="$2"
        shift 2
        ;;
        --proxy=* )
        PROXY="${1#*=}"
        shift 1
        ;;
        -r )
        REGISTRY="$2"
        shift 2
        ;;
        --registry=* )
        REGISTRY="${1#*=}"
        shift 1
        ;;
        -h )
        HOSTNAME="$2"
        shift 2
        ;;
        --hostname=* )
        HOSTNAME="${1#*=}"
        shift 1
        ;;
        -cid )
        CID="$2"
        shift 2
        ;;
        --pod-cidr=* )
        CID="${1#*=}"
        shift 1
        ;;
        * )
        echo "[$(date)] Unknow argument: $1">&2
        usage
        ;;
    esac
done

cancelSwap
openMasterFireWall
setProxy
installk8s
setup
calico
unsetProxy
