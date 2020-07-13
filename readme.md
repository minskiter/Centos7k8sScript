### Centos 7 K8s Scripts Quick Start

Author: Minskiter

- docker.sh # install docker ce
- k8s-master.sh # install k8s master node

### How to use
1. clone this repo
2. run docker.sh
3. run k8s-master.sh

### Use proxy for install k8s
``` sh
./k8s-master.sh -p http://localhost:1080
```

### Join Token
``` sh
cat $HOME/temp/*
```

### More scripts coming soon!
