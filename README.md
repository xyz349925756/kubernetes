
# 【Update】

新增下面镜像

```sh
[root@memcached ~]# kubeadm config images list
k8s.gcr.io/kube-apiserver:v1.23.5
k8s.gcr.io/kube-controller-manager:v1.23.5
k8s.gcr.io/kube-scheduler:v1.23.5
k8s.gcr.io/kube-proxy:v1.23.5
k8s.gcr.io/etcd:3.5.1-0
```



# 第一种方法

此仓库包含：

<a name="gf">官方镜像</a>

```sh
k8s.gcr.io/metrics-server/metrics-server:v0.5.2
k8s.gcr.io/ingress-nginx/controller:v1.0.5
k8s.gcr.io/ingress-nginx/kube-webhook-certgen:v1.1.1
k8s.gcr.io/coredns/coredns:v1.8.6
k8s.gcr.io/pause:3.6
```

> 这里我们使用metrics-server为例

## 1.先下载镜像

https://github.com/xyz349925756/kubernetes/actions/runs/1504468381

![image-20211126002110691](README.assets/image-20211126002110691.png)

## 2.上传镜像到装有docker环境的主机

```sh
[root@master01 ~]# docker images
REPOSITORY                                      TAG       IMAGE ID       CREATED       SIZE
tomcat                                          10.0.13   c36416c8feac   2 days ago    684MB
tomcat                                          latest    904a98253fbf   7 days ago    680MB
nginx                                           latest    ea335eea17ab   8 days ago    141MB
k8s.gcr.io/ingress-nginx/controller             v1.0.5    89ed8c731a38   9 days ago    285MB
busybox                                         latest    7138284460ff   13 days ago   1.24MB
k8s.gcr.io/pause                                3.5       4d13372e07fe   2 weeks ago   819kB
calico/node                                     v3.21.0   f2ff8e948456   2 weeks ago   189MB
calico/pod2daemon-flexvol                       v3.21.0   21bd0499378c   2 weeks ago   21.4MB
calico/cni                                      v3.21.0   19c5757ec6bb   2 weeks ago   239MB
calico/kube-controllers                         v3.21.0   5235846386af   2 weeks ago   132MB
kubernetesui/dashboard                          v2.4.0    72f07539ffb5   5 weeks ago   221MB
k8s.gcr.io/ingress-nginx/kube-webhook-certgen   v1.1.1    c41e9fcadf5a   6 weeks ago   47.7MB
k8s.gcr.io/coredns/coredns                      v1.8.6    ebe3eb74c235   7 weeks ago   46.8MB
busybox                                         1.28      8c811b4aec35   3 years ago   1.15MB
[root@master01 ~]# rz -E
rz waiting to receive.

[root@master01 ~]# unzip metrics-server-v0.5.2.zip 
Archive:  metrics-server-v0.5.2.zip
  inflating: metrics-server.tar  
  
[root@master01 ~]# docker load < metrics-server.tar 
6d75f23be3dd: Loading layer [==================================================>]  3.697MB/3.697MB
b2839a50be1a: Loading layer [==================================================>]  61.97MB/61.97MB
Loaded image: k8s.gcr.io/metrics-server/metrics-server:v0.5.2

[root@master01 ~]# docker images
REPOSITORY                                      TAG       IMAGE ID       CREATED       SIZE
tomcat                                          10.0.13   c36416c8feac   2 days ago    684MB
tomcat                                          latest    904a98253fbf   7 days ago    680MB
nginx                                           latest    ea335eea17ab   8 days ago    141MB
k8s.gcr.io/metrics-server/metrics-server        v0.5.2    f73640fb5061   9 days ago    64.3MB
k8s.gcr.io/ingress-nginx/controller             v1.0.5    89ed8c731a38   9 days ago    285MB
busybox                                         latest    7138284460ff   13 days ago   1.24MB
k8s.gcr.io/pause                                3.5       4d13372e07fe   2 weeks ago   819kB
calico/node                                     v3.21.0   f2ff8e948456   2 weeks ago   189MB
calico/pod2daemon-flexvol                       v3.21.0   21bd0499378c   2 weeks ago   21.4MB
calico/cni                                      v3.21.0   19c5757ec6bb   2 weeks ago   239MB
calico/kube-controllers                         v3.21.0   5235846386af   2 weeks ago   132MB
kubernetesui/dashboard                          v2.4.0    72f07539ffb5   5 weeks ago   221MB
k8s.gcr.io/ingress-nginx/kube-webhook-certgen   v1.1.1    c41e9fcadf5a   6 weeks ago   47.7MB
k8s.gcr.io/coredns/coredns                      v1.8.6    ebe3eb74c235   7 weeks ago   46.8MB
busybox                                         1.28      8c811b4aec35   3 years ago   1.15MB

[root@master01 ~]# wget https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

[root@master01 ~]# grep image components.yaml 
        image: k8s.gcr.io/metrics-server/metrics-server:v0.5.2
        imagePullPolicy: IfNotPresent
```

![image-20211126002705874](README.assets/image-20211126002705874.png)

```sh
[root@master01 ~]# kubectl create -f components.yaml 
serviceaccount/metrics-server created
clusterrole.rbac.authorization.k8s.io/system:aggregated-metrics-reader created
clusterrole.rbac.authorization.k8s.io/system:metrics-server created
rolebinding.rbac.authorization.k8s.io/metrics-server-auth-reader created
clusterrolebinding.rbac.authorization.k8s.io/metrics-server:system:auth-delegator created
clusterrolebinding.rbac.authorization.k8s.io/system:metrics-server created
service/metrics-server created
deployment.apps/metrics-server created
apiservice.apiregistration.k8s.io/v1beta1.metrics.k8s.io created

[root@master01 ~]# kubectl get pod -n kube-system 
NAME                                       READY   STATUS    RESTARTS         AGE
calico-kube-controllers-7d7bbc4464-h7wcq   1/1     Running   20 (3h11m ago)   3d14h
calico-node-2sdkt                          1/1     Running   14 (3h11m ago)   4d
calico-node-9vbcn                          1/1     Running   11 (3h11m ago)   4d
coredns-6cf54f794c-7rmgx                   1/1     Running   11 (3h11m ago)   4d
coredns-6cf54f794c-tn5h4                   1/1     Running   11 (3h11m ago)   4d
metrics-server-dbf765b9b-cgxh5             1/1     Running   0                59s

[root@master01 ~]# kubectl top pod -A
NAMESPACE       NAME                                       CPU(cores)   MEMORY(bytes)   
dev             nginx-deployment-694d6c9559-7mdqr          0m           1Mi             
dev             nginx-deployment-694d6c9559-mz5p8          0m           6Mi             
dev             tomcat-deployment-59ffc6d89f-k2pmk         3m           78Mi            
dev             tomcat-deployment-59ffc6d89f-p5kg9         3m           94Mi            
ingress-nginx   ingress-nginx-controller-d6cdcc5d8-bqf8j   3m           91Mi            
kube-system     calico-kube-controllers-7d7bbc4464-h7wcq   9m           18Mi            
kube-system     calico-node-2sdkt                          56m          161Mi           
kube-system     calico-node-9vbcn                          82m          161Mi           
kube-system     coredns-6cf54f794c-7rmgx                   4m           11Mi            
kube-system     coredns-6cf54f794c-tn5h4                   6m           11Mi            
kube-system     metrics-server-dbf765b9b-ftj8w             14m          25Mi            
[root@master01 ~]# kubectl top node
NAME       CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%   
master01   423m         42%    1163Mi          30%       
node01     372m         37%    958Mi           25%    
```

## 3.下载地址

| 名称                               | 下载地址                                                     | 版本    |
| ---------------------------------- | ------------------------------------------------------------ | ------- |
| kube-apiserver                     | [![kube-apiserver](https://github.com/xyz349925756/kubernetes/actions/workflows/docker_kube-apiserver_image.yml/badge.svg)](https://github.com/xyz349925756/kubernetes/actions/workflows/docker_kube-apiserver_image.yml) | v1.23.5 |
| kube-controller-manager            | [![kube-controller-manager](https://github.com/xyz349925756/kubernetes/actions/workflows/docker_kube-controller-manager_image.yml/badge.svg)](https://github.com/xyz349925756/kubernetes/actions/workflows/docker_kube-controller-manager_image.yml) | v1.23.5 |
| kube-scheduler                     | [![kube-scheduler](https://github.com/xyz349925756/kubernetes/actions/workflows/docker_kube-scheduler_image.yml/badge.svg)](https://github.com/xyz349925756/kubernetes/actions/workflows/docker_kube-scheduler_image.yml) | v1.23.5 |
| kube-proxy                         | [![kube-proxy](https://github.com/xyz349925756/kubernetes/actions/workflows/docker_kube-proxy_image.yml/badge.svg)](https://github.com/xyz349925756/kubernetes/actions/workflows/docker_kube-proxy_image.yml) | v1.23.5 |
| etcd                               | [![etcd](https://github.com/xyz349925756/kubernetes/actions/workflows/docker_etcd_image.yml/badge.svg)](https://github.com/xyz349925756/kubernetes/actions/workflows/docker_etcd_image.yml) | 3.5.1-0 |
| metrics-server                     | [![Metrics-Server](https://github.com/xyz349925756/kubernetes/actions/workflows/docker_metrics-server_image.yml/badge.svg)](https://github.com/xyz349925756/kubernetes/actions/workflows/docker_metrics-server_image.yml) | v0.5.2  |
| ingress-nginx/controller           | [![Ingress-Nginx-Controller](https://github.com/xyz349925756/kubernetes/actions/workflows/docker_ingress-nginx-controller_image.yml/badge.svg)](https://github.com/xyz349925756/kubernetes/actions/workflows/docker_ingress-nginx-controller_image.yml) | v1.0.5  |
| ingress-nginx/kube-webhook-certgen | [![Ingress-Nginx-Kube-webhook-certgen](https://github.com/xyz349925756/kubernetes/actions/workflows/docker_ingress-nginx-kube-webhook-certgen_image.yml/badge.svg)](https://github.com/xyz349925756/kubernetes/actions/workflows/docker_ingress-nginx-kube-webhook-certgen_image.yml) | v1.1.1  |
| coredns                            | [![CoreDNS](https://github.com/xyz349925756/kubernetes/actions/workflows/docker_coredns_image.yml/badge.svg)](https://github.com/xyz349925756/kubernetes/actions/workflows/docker_coredns_image.yml) | v1.8.6  |
| pause                              | [![Pause](https://github.com/xyz349925756/kubernetes/actions/workflows/docker_pause_image.yml/badge.svg)](https://github.com/xyz349925756/kubernetes/actions/workflows/docker_pause_image.yml) | 3.6     |





# 第二种方法

Docker Hub: https://hub.docker.com/r/xyz349925756

​           https://hub.docker.com/u/xyz349925756

详细使用方法点击进去每个镜像里面就可以看到使用方法

通用方法！！

```sh
# 拉取镜像语法
$ docker pull xyz349925756/images_name:version

#修改tag为官网匹配的命名
$ docker tag  xyz349925756/images_name:version  k8s.gcr.io/images_name:version

#删除以前的
$ docker rmi xyz349925756/images_name:version
```

![image-20211126221033170](README.assets/image-20211126221033170.png)

拉取k8s.gcr.io国外镜像。

服务版本：linux/amd64  

*使用docker你可以使用shell 直接拉取对应的镜像即可,参考脚本*

```sh
[root@memcached ~]# vim pull_image.sh
#/bin/bash  
One_Image=(
  kube-apiserver:v1.23.5 
  kube-controller-manager:v1.23.5 
  kube-scheduler:v1.23.5 
  kube-proxy:v1.23.5 
  etcd:3.5.1-0
  pause:3.6
)

Two_Image=(
  metrics-server:v0.5.2
  coredns:v1.8.6
)

Three_Image=(
  ingress-nginx-controller:v1.0.5
  ingress-nginx-kube-webhook-certgen:v1.1.1
)

for imagename in ${One_Image[@]};
do 
  docker pull docker.io/xyz349925756/${imagename}
  docker tag docker.io/xyz349925756/${imagename} k8s.gcr.io/${imagename}
  docker rmi docker.io/xyz349925756/${imagename}
done

for imagename2 in ${Two_Image[@]};
do 
  docker pull docker.io/xyz349925756/${imagename2}
  docker tag docker.io/xyz349925756/${imagename2} k8s.gcr.io/`echo $imagename2|awk -F":" '{print $1}'`/${imagename2}
  docker rmi docker.io/xyz349925756/${imagename2}
done

for imagename3 in ${Three_Image[@]};
do 
  docker pull docker.io/xyz349925756/${imagename3}
  docker tag docker.io/xyz349925756/${imagename3} k8s.gcr.io/ingress-nginx/`echo $imagename3|awk -F"nginx-" '{print $2}'`
  docker rmi docker.io/xyz349925756/${imagename3}
done


[root@memcached ~]# sh pull_image.sh 
...

[root@memcached ~]# docker images
REPOSITORY                                      TAG                 IMAGE ID            CREATED             SIZE
k8s.gcr.io/kube-apiserver                       v1.23.5             3fc1d62d6587        3 weeks ago         135 MB
k8s.gcr.io/kube-proxy                           v1.23.5             3c53fa8541f9        3 weeks ago         112 MB
k8s.gcr.io/kube-scheduler                       v1.23.5             884d49d6d8c9        3 weeks ago         53.5 MB
k8s.gcr.io/kube-controller-manager              v1.23.5             b0c9e5e4dbb1        3 weeks ago         125 MB
k8s.gcr.io/metrics-server/metrics-server        v0.5.2              f73640fb5061        4 months ago        64.3 MB
k8s.gcr.io/ingress-nginx/controller             v1.0.5              89ed8c731a38        4 months ago        285 MB
k8s.gcr.io/etcd                                 3.5.1-0             25f8c7f3da61        5 months ago        293 MB
k8s.gcr.io/ingress-nginx/kube-webhook-certgen   v1.1.1              c41e9fcadf5a        5 months ago        47.7 MB
k8s.gcr.io/coredns/coredns                      v1.8.6              a4ca41631cc7        6 months ago        46.8 MB
k8s.gcr.io/pause                                3.6                 6270bb605e12        7 months ago        683 kB

# 对比官方镜像名称
k8s.gcr.io/kube-apiserver:v1.23.5
k8s.gcr.io/kube-controller-manager:v1.23.5
k8s.gcr.io/kube-scheduler:v1.23.5
k8s.gcr.io/kube-proxy:v1.23.5
k8s.gcr.io/etcd:3.5.1-0
k8s.gcr.io/metrics-server/metrics-server:v0.5.2
k8s.gcr.io/ingress-nginx/controller:v1.0.5
k8s.gcr.io/ingress-nginx/kube-webhook-certgen:v1.1.1
k8s.gcr.io/coredns/coredns:v1.8.6
k8s.gcr.io/pause:3.6
```



# 第三种方法

github packages

进入packages:https://github.com/xyz349925756?tab=packages&repo_name=kubernetes

![image-20211127201449535](README.assets/image-20211127201449535.png)

进入packages点击需要的镜像。

![image-20211127201543761](README.assets/image-20211127201543761.png)

```sh
$ docker pull ghcr.io/xyz349925756/pause-3.6:3.6

拉取之后参考上面的官网镜像修改tag
$ docker tag ghcr.io/xyz349925756/pause-3.6:3.6 k8s.gcr.io/pause:3.6
```

参考[官方名称](#gf)
