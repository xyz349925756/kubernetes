#这是个人拉取k8s.scr.io镜像设置的仓库
如果你需要帮助可以联系我微信：Fly_349925756
> 使用方法后续补上
```bash
[root@master01 ~]# git clone git://github.com/xyz349925756/kubernetes.git
[root@master01 ~]# cd kubernetes/k8s.gcr.io/coredns/
[root@master01 ~/kubernetes/k8s.gcr.io/coredns]# ls
coredns-1.8.6  Dockerfile


[root@master01 ~/kubernetes/k8s.gcr.io/coredns]#  docker load < coredns-1.8.6 
  256bc5c338a6: Loading layer [==================================================>]  336.4kB/336.4kB
  80e4a2390030: Loading layer [==================================================>]  46.62MB/46.62MB
  Loaded image: k8s.gcr.io/coredns/coredns:v1.8.6
[root@master01 ~/kubernetes/k8s.gcr.io/coredns]#  docker images
REPOSITORY                   TAG       IMAGE ID       CREATED        SIZE
k8s.gcr.io/pause             3.5       4d13372e07fe   25 hours ago   819kB
k8s.gcr.io/pause             3.6       4d13372e07fe   25 hours ago   819kB
calico/node                  v3.21.0   f2ff8e948456   6 days ago     189MB
calico/pod2daemon-flexvol    v3.21.0   21bd0499378c   6 days ago     21.4MB
calico/cni                   v3.21.0   19c5757ec6bb   6 days ago     239MB
k8s.gcr.io/coredns/coredns   v1.8.6    ebe3eb74c235   5 weeks ago    46.8MB


```
上面就是使用方法pause一样的使用
