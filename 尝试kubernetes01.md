因为多次失败，根据Gitbook中的教程走一遍看看。

首先安装一下gcloud 工具，然后对比操作。{} 表示多台机器操作  {{}}配置文件修改项

命令自动补全

```BASH
echo 'source /usr/share/bash-completion/bash_completion' >> ~/.bashrc
echo 'source <(kubectl completion bash)' >> ~/.bashrc
source ~/.bashrc
```

服务检查脚本

```BASH
[root@master01 ~]# cat service_check.sh
#!/bin/bash
#后面做个判断的
echo "Kube-apiserver_Check......"
#apiserver 检查
echo "+-------------------------------------------------------+";
for host in master01 master02;do for i in kube-apiserver kube-controller-manager kube-scheduler;
do echo -e "    $host  $i is : \c" && ssh $host systemctl status $i|grep Active |awk -F"[()]" '{print $2}' ;done;done
echo "+-------------------------------------------------------+";

echo "Etcd_Check......"
echo "+-------------------------------------------------------+";
#etcd检查
for host in master01 master02 node01;do echo -e "    $host  etcd is  |  \c" && ssh $host systemctl status etcd|grep Active |awk -F"[()]" '{print $2}' ;done
echo "+-------------------------------------------------------+";

echo "Kube-proxy kubelet_Check......"
#kubelet,proxy检查
echo "+-------------------------------------------------------+";
for host in master01 master02 node01 node02 harbor;do for i in kube-proxy kubelet;
do echo -e "    $host  $i is : \c" && ssh $host systemctl status $i|grep Active |awk -F"[()]" '{print $2}' ;done;done
echo "+-------------------------------------------------------+";

```





# 二进制部署

建立机器互信

```bash
[root@harbor ~]# ssh-keygen -t rsa
[root@harbor ~]# ssh-copy-id root@172.16.0.160
[root@harbor ~]# ssh-copy-id root@172.16.0.161
[root@harbor ~]# ssh-copy-id root@172.16.0.165
[root@harbor ~]# ssh-copy-id root@172.16.0.166
[root@harbor ~]# ssh-copy-id root@172.16.0.170
```

## Docker

docker-compose
https://github.com/docker/compose/releases

```bash
[root@harbor /server/soft]# tar xf docker-20.10.7.tgz 
[root@harbor /server/soft]# for host in master01 master02 node01 node02 harbor;do scp docker/* root@$host:/usr/bin/;done
[root@harbor /server/soft]# for host in master01 master02 node01 node02 harbor;do scp docker-compose-Linux-x86_64 root@$host:/usr/bin/docker-compose ;done

{   #xshell 撰写操作 下文使用all 替代！
[root@harbor /server/soft]# docker --version
[root@harbor /server/soft]# chmod +x /usr/bin/docker-compose
[root@harbor /server/soft]# docker-compose --version
}

#systemd管理docker
[root@harbor /server/soft]# cat > /usr/lib/systemd/system/docker.service << EOF
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target firewalld.service
Wants=network-online.target
[Service]
Type=notify
ExecStart=/usr/bin/dockerd
ExecReload=/bin/kill -s HUP $MAINPID
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
TimeoutStartSec=0
Delegate=yes
KillMode=process
Restart=on-failure
StartLimitBurst=3
StartLimitInterval=60s
[Install]
WantedBy=multi-user.target
EOF

[root@harbor /server/soft]# for host in master01 master02 node01 node02 harbor;do scp /usr/lib/systemd/system/docker.service root@$host:/usr/lib/systemd/system/;done

{  #开启docker all
[root@harbor /server/soft]# systemctl daemon-reload && systemctl start docker && systemctl enable docker
[root@harbor /server/soft]# systemctl status docker |grep Active
   Active: active (running) since Sat 2021-06-26 15:40:35 CST; 24s ago

}
```

## cfssl证书

| 名称(json)              | CN                                 | host             | profile    | O                  | OU         |
| ----------------------- | ---------------------------------- | ---------------- | ---------- | ------------------ | ---------- |
| **ca-csr**              | **harbor**                         | **-**            | **-**      | **harbor**         | **system** |
| **ca-config**           | **-**                              | **-**            | **harbor** | **-**              | **-**      |
| **harbor-csr**          | **harbor**                         | **172.16.0.170** | **-**      | **harbor**         | **system** |
| ca-csr                  |                                    |                  |            |                    |            |
| ca-config               |                                    |                  |            |                    |            |
| etcd-csr                |                                    |                  |            |                    |            |
| apiserver-csr           |                                    |                  |            |                    |            |
| kube-controller-manager | **system:kube-controller-manager** |                  |            | **system:masters** |            |
| kube-scheduler          | **system:kube-scheduler**          |                  |            |                    |            |
| kubelet-csr             |                                    |                  |            |                    |            |
| kube-proxy-csr          |                                    |                  |            |                    |            |
| admin-csr               | **kubernetes-admin**               |                  |            | **system:masters** |            |
|                         |                                    |                  |            |                    |            |

### cfssl cli 

```bash
#下载并上传cfssl
[root@harbor /server/soft]# chmod +x cfssl*
#执行权限
[root@harbor /server/soft]# ll
-rwxr-xr-x 1 root root  16377936 Jun 24 21:39 cfssl_1.6.0_linux_amd64
-rwxr-xr-x 1 root root  13245520 Jun 24 21:39 cfssl-certinfo_1.6.0_linux_amd64
-rwxr-xr-x 1 root root  10892112 Jun 24 21:39 cfssljson_1.6.0_linux_amd64
#把命令添加到/usr/bin
[root@harbor /server/soft]# mv cfssl_1.6.0_linux_amd64 /usr/bin/cfssl
[root@harbor /server/soft]# mv cfssljson_1.6.0_linux_amd64 /usr/bin/cfssljson
[root@harbor /server/soft]# mv cfssl-certinfo_1.6.0_linux_amd64 /usr/bin/cfssl-certinfo
```

### harbor

下载：https://github.com/goharbor/harbor/releases

```bash
#解压harbor
[root@harbor /server/soft]# tar xf harbor-offline-installer-v2.3.0-rc3.tgz  -C /opt/
[root@harbor /server/soft]# cd  /opt/harbor/
[root@harbor /opt/harbor]# ls
common.sh  harbor.v2.3.0.tar.gz  harbor.yml.tmpl  install.sh  LICENSE  prepare
[root@harbor /opt/harbor]# cp harbor.yml.tmpl{,.bak}
[root@harbor /opt/harbor]# mv harbor.yml.tmpl harbor.yml
[root@harbor /opt/harbor]# cd /root/tls/harbor
```

证书

```bash
#证书请求凭证
cat > ca-csr.json <<EOF
{
    "CN": "harbor",   
    "hosts": [],     
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "ST": "yunnan",
            "L": "kunming",
            "O": "harbor",
            "OU": "S"
        }
    ],
    "ca": {
        "expiry": "175200h" 
    }
}
EOF
#配置CA
cat >ca-config.json<<EOF
{
    "signing": {
        "default": {
            "expiry": "175200h"
        },
        "profiles": {
            "harbor": {
                "expiry": "175200h",
                "usages": [
                    "signing",
                    "key encipherment",
                    "server auth",
                    "client auth"
                ]
            }
          
        }
    }
}
EOF

[root@harbor ~/tls/harbor]# cfssl gencert -initca ca-csr.json |cfssljson -bare ca
[root@harbor ~/tls/harbor]# ls
ca-config.json  ca.csr  ca-csr.json  ca-key.pem  ca.pem
#配置harbor服务
cat >harbor-csr.json <<EOF
{
    "CN": "harbor",
    "hosts": [
      "172.16.0.170"                                                
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "ST": "kunming",
            "L": "kunming",
            "O": "harbor",
            "OU": "ops"
        }
    ]
}
EOF

[root@harbor ~/tls/harbor]# cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=harbor harbor-csr.json | cfssljson -bare harbor

[root@harbor ~/tls/harbor]# ls
ca-config.json  ca-csr.json  ca.pem      harbor-csr.json  harbor.pem
ca.csr          ca-key.pem   harbor.csr  harbor-key.pem
```

访问配置

```bash
{# all
[root@harbor ~/tls/harbor]# mkdir -p /etc/docker/certs.d/harbor
}
#服务器端操作
[root@harbor ~/tls/harbor]# cp /root/tls/harbor/harbor.pem /etc/docker/certs.d/harbor/harbor.crt
[root@harbor ~/tls/harbor]# cp /root/tls/harbor/harbor.pem ~
[root@harbor ~/tls/harbor]# cd
[root@harbor ~]# cat host.txt 
master01
master02
node01
node02
harbor
#后期下发使用
[root@harbor ~]# for host in `cat /root/host.txt`;do scp /etc/docker/certs.d/harbor/harbor.crt root@$host:/etc/docker/certs.d/harbor/ ;done
[root@harbor ~]# for host in `cat /root/host.txt`;do scp /root/harbor.pem root@$host:~ ;done
[root@harbor ~]# mkdir /data     #容器存储持久化
[root@harbor /opt/harbor]# vim harbor.yml
{
 {
  hostname: 172.16.0.170
#http:
# port: 80
  certificate: /root/tls/harbor/harbor.pem
  private_key: /root/tls/harbor/harbor-key.pem  
harbor_admin_password: 12345      #因为演示密码旧简单点
database:
  password: root123   #自己根据实际情况修改
  }
}
[root@harbor /opt/harbor]# ./prepare #环境检查
[root@harbor /opt/harbor]# ./install.sh  #安装harbor
✔ ----Harbor has been installed and started successfully.----
#看到这个表示成功
[root@harbor /opt/harbor]# docker-compose ps #容器开启和端口映射信息
#设置开机启动
[root@harbor /opt/harbor]# chmod +x /etc/rc.d/rc.local 
[root@harbor /opt/harbor]# echo 'cd /opt/harbor && docker-compose start' >/root/docker-compose.sh
[root@harbor /opt/harbor]# echo 'sh /root/docker-compose.sh' >>/etc/rc.d/rc.local 

```

测试客户端是否可以登陆

```bash
[root@harbor /opt/harbor]# cat >/etc/docker/daemon.json<<EOF 
{
"insecure-registries": ["172.16.0.170"] 
}
EOF
[root@harbor /opt/harbor]# for host in `cat /root/host.txt`;do scp /etc/docker/daemon.json root@$host:/etc/docker/ ;done
{ #all
[root@harbor /opt/harbor]# systemctl daemon-reload && systemctl restart docker
}
#随便找一台worker 验证一下是否可以登陆
[root@node02 ~]# docker login 172.16.0.170
Username: admin
Password: 
Error response from daemon: login attempt to http://172.16.0.170/v2/ failed with status: 502 Bad Gateway

#上面问题是修改了daemon.json 文件服务没有重启
[root@harbor /opt/harbor]# docker-compose stop && docker-compose start

#重启一下在尝试
[root@node02 ~]# docker login 172.16.0.170
Username: admin
Password: 
WARNING! Your password will be stored unencrypted in /root/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store

Login Succeeded

####################功能测试####################################

[root@node02 ~]# docker pull busybox   
Using default tag: latest
latest: Pulling from library/busybox
b71f96345d44: Pull complete 
Digest: sha256:930490f97e5b921535c153e0e7110d251134cc4b72bbb8133c6a5065cc68580d
Status: Downloaded newer image for busybox:latest
docker.io/library/busybox:latest
[root@node02 ~]# docker images
REPOSITORY   TAG       IMAGE ID       CREATED       SIZE
busybox      latest    69593048aa3a   2 weeks ago   1.24MB
[root@node02 ~]# docker tag 69593048aa3a 172.16.0.170/library/busybox:1.33.1
[root@node02 ~]# docker images
REPOSITORY                     TAG       IMAGE ID       CREATED       SIZE
busybox                        latest    69593048aa3a   2 weeks ago   1.24MB
172.16.0.170/library/busybox   1.33.1    69593048aa3a   2 weeks ago   1.24MB
[root@node02 ~]# docker push 172.16.0.170/library/busybox:1.33.1
The push refers to repository [172.16.0.170/library/busybox]
5b8c72934dfc: Pushed 
1.33.1: digest: sha256:dca71257cd2e72840a21f0323234bb2e33fea6d949fa0f21c5102146f583486b size: 527
##################################################################
```

## kubernetes证书

```bash
[root@harbor /opt/harbor]# file=/root/tls/kubernetes
[root@harbor /opt/harbor]# mkdir -p $file && cd $file
#新建ca配置文件
[root@harbor ~/tls/kubernetes]# cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "175200h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "175200h"
      }
    }
  }
}
EOF
#新建CA凭证签发请求文件
[root@harbor ~/tls/kubernetes]# cat > ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "L": "kunming",
      "O": "Kubernetes",
      "OU": "System",
      "ST": "yunnan"
    }
  ]
}
EOF
#生成凭证和私钥
[root@harbor ~/tls/kubernetes]# cfssl gencert -initca ca-csr.json | cfssljson -bare ca
[root@harbor ~/tls/kubernetes]# ls
ca-config.json  ca.csr  ca-csr.json  ca-key.pem  ca.pem
```

### clinet 与server凭证

使用server和clinet别于梳理集群人、验证关系特别是etcd与apiserver 通信

```bash
#一个用于kubernetes admin 用户的clinet凭证
#admin clinet凭证签发请求
cat > admin-csr.json <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "L": "kunming",
      "O": "system:masters",
      "OU": "System",
      "ST": "yunnan"
    }
  ]
}
EOF
#Kubernetes The Hard Way  组织
[root@harbor ~/tls/kubernetes]# cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  admin-csr.json | cfssljson -bare admin
[root@harbor ~/tls/kubernetes]# ls admin*.pem
 admin-key.pem  
 admin.pem     
```

### kubelet 客户端凭证

kubernetes 使用special-purpose authorization mode (node鉴权)授权来自kubelet的API请求。为了通过node 鉴权的授权，kubelet必须使用一个署名为:system:node:<nodename>的凭证来证明它属于system:nodes用户组。node鉴权要求

每一台node的凭证

```bash
for instance in `cat /root/host.txt`; do
cat > ${instance}-csr.json <<EOF
{
  "CN": "system:node:${instance}",
  "hosts":[
      "127.0.0.1",
      "172.16.0.160",
      "172.16.0.161",
      "172.16.0.162",
      "172.16.0.163",
      "172.16.0.164",
      "172.16.0.165",
      "172.16.0.166",
      "172.16.0.167",
      "172.16.0.168",
      "172.16.0.169",
      "172.16.0.170"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "L": "kunming",
      "O": "system:nodes",
      "OU": "System",
      "ST": "yunnan"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  ${instance}-csr.json | cfssljson -bare ${instance}
done

[root@harbor ~/tls/kubernetes]# for host in `cat /root/host.txt`;do ls $host*.pem;done
master01-key.pem   master02.pem       node01.pem       node02.pem       harbor.pem
master01.pem       master02-key.pem   node01-key.pem   node02-key.pem   harbor-key.pem

#这里是最大的问题
```

### kube-controller-manager客户端凭证

```bash
cat > kube-controller-manager-csr.json <<EOF
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "L": "kunming",
      "O": "system:kube-controller-manager",
      "OU": "System",
      "ST": "yunnan"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager
  
[root@harbor ~/tls/kubernetes]# ls kube-controller-manager*.pem
kube-controller-manager-key.pem   kube-controller-manager.pem       
```

### kube-proxy 客户端凭证

```BASH
cat > kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "L": "kunming",
      "O": "system:node-proxy",
      "OU": "System",
      "ST": "yunnan"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-proxy-csr.json | cfssljson -bare kube-proxy
  
[root@harbor ~/tls/kubernetes]# ls  kube-proxy*.pem 
kube-proxy.pem   kube-proxy-key.pem                
```

### kube-scheduler凭证

```BASH
cat > kube-scheduler-csr.json <<EOF
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "L": "kunming",
      "O": "system:kube-scheduler",
      "OU": "System",
      "ST": "yunnan"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-scheduler-csr.json | cfssljson -bare kube-scheduler
  
[root@harbor ~/tls/kubernetes]# ls kube-scheduler*.pem
kube-scheduler-key.pem  kube-scheduler.pem

```

### kubernetes api server 证书

为了保证客户端与kubernetes API 的认证，kubernetes api server凭证中必须包含kubernetes的静态IP地址

```BASH
#apiserver 证书请求
cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
      "hosts": [
      "10.0.0.1",
      "127.0.0.1",
      "172.16.0.160",
      "172.16.0.161",
      "172.16.0.162",
      "172.16.0.163",
      "172.16.0.164",
      "172.16.0.165",
      "172.16.0.166",
      "172.16.0.167",
      "172.16.0.168",
      "172.16.0.169",
      "172.16.0.170",
      "kubernetes",
      "kubernetes.default",
      "kubernetes.default.svc",
      "kubernetes.default.svc.cluster",
      "kubernetes.default.svc.cluster.local"
    ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "L": "kunming",
      "O": "Kubernetes",
      "OU": "System",
      "ST": "yunnan"
    }
  ]
}
EOF

#创建凭证与私钥
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=10.32.0.1,10.240.0.10,10.240.0.11,10.240.0.12,${KUBERNETES_PUBLIC_ADDRESS},127.0.0.1,${KUBERNETES_HOSTNAMES} \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes
  
[root@harbor ~/tls/kubernetes]# cfssl gencert \
   -ca=ca.pem \
   -ca-key=ca-key.pem \
   -config=ca-config.json \
  -profile=kubernetes \
   kubernetes-csr.json | cfssljson -bare kubernetes

  
  #这里的hostname 可以写入上面证书中
[root@harbor ~/tls/kubernetes]# ls kubernetes*.pem
kubernetes-key.pem  kubernetes.pem

```

### service Account 证书

```BASH
cat > service-account-csr.json <<EOF
{
  "CN": "service-accounts",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "L": "kunming",
      "O": "Kubernetes",
      "OU": "System",
      "ST": "yunnan"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  service-account-csr.json | cfssljson -bare service-account
  
[root@harbor ~/tls/kubernetes]# ls service-account*.pem
service-account-key.pem  service-account.pem

```

#### 创建所需目录结构

```BASH
[root@master01 ~]# mkdir -p /opt/{etcd,kubernetes}/{cfg,log,ssl}
[root@master01 ~]# tree /opt -L 3
/opt 
├── containerd          #docker 生成的
│   ├── bin
│   └── lib
├── etcd
│   ├── cfg
│   ├── log
│   └── ssl
└── kubernetes
    ├── cfg
    ├── log
    └── ssl
#etcd bin这里不需要全部移动到/usr/bin/下
```



### 分发客户端和服务器证书

```BASH
[root@harbor ~/tls/kubernetes]# for instance in `cat /root/host.txt`;do scp /root/tls/kubernetes/{ca,${instance}-key,${instance}}.pem ${instance}:/opt/kubernetes/ssl/;done
ca.pem                             100% 1314   619.2KB/s   00:00    
master01-key.pem                   100% 1679   490.0KB/s   00:00    
master01.pem                       100% 1558   422.6KB/s   00:00    
ca.pem                             100% 1314   617.5KB/s   00:00    
master02-key.pem                   100% 1679     1.2MB/s   00:00    
master02.pem                       100% 1558     1.3MB/s   00:00    
ca.pem                             100% 1314   355.9KB/s   00:00    
node01-key.pem                     100% 1675   303.3KB/s   00:00    
node01.pem                         100% 1558   374.2KB/s   00:00    
ca.pem                             100% 1314   598.0KB/s   00:00    
node02-key.pem                     100% 1675   769.7KB/s   00:00    
node02.pem                         100% 1558   696.3KB/s   00:00    
ca.pem                             100% 1314     1.0MB/s   00:00    
harbor-key.pem                     100% 1679   773.0KB/s   00:00    
harbor.pem                         100% 1558   739.9KB/s   00:00    
```

### 分发服务器证书

```BASH
#etcd 3台：master01 、master02 、node01
#apiserver 2台 master01、master02

[root@harbor ~/tls/kubernetes]# for instance in master01 master02 node01; do \
    scp ca.pem kubernetes-key.pem kubernetes.pem \
    ${instance}:/opt/etcd/ssl
done
ca.pem                                    100% 1314   572.1KB/s   00:00    
kubernetes-key.pem                        100% 1675    80.6KB/s   00:00    
kubernetes.pem                            100% 1728   849.7KB/s   00:00    
ca.pem                                    100% 1314   480.3KB/s   00:00    
kubernetes-key.pem                        100% 1675   821.5KB/s   00:00    
kubernetes.pem                            100% 1728   802.7KB/s   00:00    
ca.pem                                    100% 1314   576.1KB/s   00:00    
kubernetes-key.pem                        100% 1675   955.6KB/s   00:00    
kubernetes.pem                            100% 1728     1.1MB/s   00:00    

[root@harbor ~/tls/kubernetes]# for instance in master01 master02; do \
    scp ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
    service-account-key.pem service-account.pem ${instance}:/opt/kubernetes/ssl
done
ca.pem                                    100% 1314   638.8KB/s   00:00    
ca-key.pem                                100% 1675   647.2KB/s   00:00    
kubernetes-key.pem                        100% 1675   946.0KB/s   00:00    
kubernetes.pem                            100% 1728   992.3KB/s   00:00    
service-account-key.pem                   100% 1675   835.6KB/s   00:00    
service-account.pem                       100% 1436   698.9KB/s   00:00    
ca.pem                                    100% 1314   566.3KB/s   00:00    
ca-key.pem                                100% 1675   651.0KB/s   00:00    
kubernetes-key.pem                        100% 1675   700.4KB/s   00:00    
kubernetes.pem                            100% 1728   972.3KB/s   00:00    
service-account-key.pem                   100% 1675   996.6KB/s   00:00    
service-account.pem                       100% 1436   898.5KB/s   00:00    
```

## 配置生成配置

kubeconfig配置文件（访问集群必须的文件），它们是kubernetes客户端与apiserver认证与鉴权的保证

#### kubectl 安装

```BASH
[root@harbor ~/tls/kubernetes]# cd /server/soft/
[root@harbor /server/soft]# tar xf kubernetes-server-linux-amd64.tar.gz 
[root@harbor /server/soft]# cd kubernetes/server/bin/
[root@harbor /server/soft/kubernetes/server/bin]# cp kubectl kubeadm /usr/bin/
[root@harbor /server/soft/kubernetes/server/bin]# cd /root/tls/kubernetes/
[root@harbor ~/tls/kubernetes]# 
```

### 客户端认证配置

用于**kube-proxy**、 **kube-controller-manager、kube-scheduler、kubelet**的kubeconfig文件

kubernetes 共有IP地址（私网或者公网）也就是apiserver的地址

每一个kubeconfig文件都需要一个kubeapiserver的IP地址，为高可用性，我们可以把该IP分配给apiserver之前的lb vip

查询kubernetes-the-hard-way的静态IP地址

```BASH
KUBERNETES_PUBLIC_ADDRESS=172.16.0.160
```

### kubelet 配置文件

为了确保node authorizer 授权（鉴权），kubelet配置文件中的客户端证书必须匹配node名字

为每个worker节点创建kubeconfig：

```BASH
for instance in `cat /root/host.txt`; do
  kubectl config set-cluster kubernetes \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
    --kubeconfig=/opt/kubernetes/cfg/${instance}.kubeconfig

  kubectl config set-credentials system:node:${instance} \
    --client-certificate=${instance}.pem \
    --client-key=${instance}-key.pem \
    --embed-certs=true \
    --kubeconfig=/opt/kubernetes/cfg/${instance}.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes \
    --user=system:node:${instance} \
    --kubeconfig=/opt/kubernetes/cfg/${instance}.kubeconfig

  kubectl config use-context default --kubeconfig=/opt/kubernetes/cfg/${instance}.kubeconfig
done

[root@harbor ~/tls/kubernetes]# tree /opt/kubernetes/cfg/
/opt/kubernetes/cfg/
├── harbor.kubeconfig
├── master01.kubeconfig
├── master02.kubeconfig
├── node01.kubeconfig
└── node02.kubeconfig

```

### kube-proxy

为kube-proxy服务生成kubeconfig配置文件

```BASH
  KUBERNETES_PUBLIC_ADDRESS=172.16.0.160
  KUBERNETES_CONFIG="/opt/kubernetes/cfg/kube-proxy.kubeconfig"
  kubectl config set-cluster kubernetes \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
    --kubeconfig=${KUBERNETES_CONFIG}

  kubectl config set-credentials system:kube-proxy \
    --client-certificate=kube-proxy.pem \
    --client-key=kube-proxy-key.pem \
    --embed-certs=true \
    --kubeconfig=${KUBERNETES_CONFIG}

  kubectl config set-context default \
    --cluster=kubernetes \
    --user=system:kube-proxy \
    --kubeconfig=${KUBERNETES_CONFIG}

  kubectl config use-context default --kubeconfig=${KUBERNETES_CONFIG}
```

### admin

```BASH
{
  KUBERNETES_PUBLIC_ADDRESS=172.16.0.160
  KUBERNETES_CONFIG="/opt/kubernetes/cfg/admin.kubeconfig"
  
  kubectl config set-cluster kubernetes \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=${KUBERNETES_CONFIG}

  kubectl config set-credentials admin \
    --client-certificate=admin.pem \
    --client-key=admin-key.pem \
    --embed-certs=true \
    --kubeconfig=${KUBERNETES_CONFIG}

  kubectl config set-context default \
    --cluster=kubernetes \
    --user=admin \
    --kubeconfig=${KUBERNETES_CONFIG}

  kubectl config use-context default --kubeconfig=${KUBERNETES_CONFIG}
}
```

### kube-controller-manager

```BASH

{
KUBERNETES_CONFIG="/opt/kubernetes/cfg/kube-controller-manager.kubeconfig"

  kubectl config set-cluster kubernetes \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=${KUBERNETES_CONFIG}

  kubectl config set-credentials system:kube-controller-manager \
    --client-certificate=kube-controller-manager.pem \
    --client-key=kube-controller-manager-key.pem \
    --embed-certs=true \
    --kubeconfig=${KUBERNETES_CONFIG}

  kubectl config set-context default \
    --cluster=kubernetes \
    --user=system:kube-controller-manager \
    --kubeconfig=${KUBERNETES_CONFIG}

  kubectl config use-context default --kubeconfig=${KUBERNETES_CONFIG}
}

```

### kube-scheduler

```BASH
#配置生成配置
{

KUBERNETES_CONFIG="/opt/kubernetes/cfg/kube-scheduler.kubeconfig"

  kubectl config set-cluster kubernetes \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=${KUBERNETES_CONFIG}

  kubectl config set-credentials system:kube-scheduler \
    --client-certificate=kube-scheduler.pem \
    --client-key=kube-scheduler-key.pem \
    --embed-certs=true \
    --kubeconfig=${KUBERNETES_CONFIG}

  kubectl config set-context default \
    --cluster=kubernetes \
    --user=system:kube-scheduler \
    --kubeconfig=${KUBERNETES_CONFIG}

  kubectl config use-context default --kubeconfig=${KUBERNETES_CONFIG}

}
```



### 配置生成密钥

Kubernetes 存储了集群状态、应用配置和密钥等很多不同的数据。而 Kubernetes 也支持集群数据的加密存储。

创建加密密钥以及一个用于加密 Kubernetes Secrets 的 [加密配置文件](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/#understanding-the-encryption-at-rest-configuration)。
*`kube-apiserver` 的参数 `--experimental-encryption-provider-config` 控制 API 数据在 etcd 中的加密方式。* 

```BASH
#加密密钥
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

加密配置文件
cat > encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF
```



#分发encryption-config.yaml文件到控制节点(etcd等下看看)

```bash
[root@harbor ~/tls/kubernetes]# for instance in master01 master02; do
   scp /opt/kubernetes/cfg/encryption-config.yaml ${instance}:/opt/kubernetes/cfg/
 done
encryption-config.yaml                 100%  240    66.3KB/s   00:00    
encryption-config.yaml                 100%  240    76.6KB/s   00:00    

[root@master01 ~]# tree /opt/kubernetes/
/opt/kubernetes/
├── cfg
│   └── encryption-config.yaml
├── log
└── ssl
    ├── ca-key.pem
    ├── ca.pem
    ├── kubernetes-key.pem
    ├── kubernetes.pem
    ├── master01-key.pem
    ├── master01.pem
    ├── service-account-key.pem
    └── service-account.pem
```

​    



### 分发配置文件

```BASH
#将kubelet 、kube-proxy kubeconfig配置文件分发到每个worker节点上
[root@harbor ~/tls/kubernetes]# cd /opt/kubernetes/cfg/
[root@harbor /opt/kubernetes/cfg]# for instance in `cat /root/host.txt`; do
  scp ${instance}.kubeconfig kube-proxy.kubeconfig ${instance}:/opt/kubernetes/cfg
done
master01.kubeconfig                     100% 6466     2.5MB/s   00:00    
kube-proxy.kubeconfig                   100% 6308     3.4MB/s   00:00    
master02.kubeconfig                     100% 6466     1.9MB/s   00:00    
kube-proxy.kubeconfig                   100% 6308     2.1MB/s   00:00    
node01.kubeconfig                       100% 6458     4.4MB/s   00:00    
kube-proxy.kubeconfig                   100% 6308     5.6MB/s   00:00    
node02.kubeconfig                       100% 6458     3.2MB/s   00:00    
kube-proxy.kubeconfig                   100% 6308     6.4MB/s   00:00    
harbor.kubeconfig                       100% 6462     4.5MB/s   00:00    
kube-proxy.kubeconfig                   100% 6308     3.1MB/s   00:00    

#将admin、kube-scheduler.kubeconfig、 kube-controller-manager.kubeconfig kubeconfig 配置文件复制到每个controller节点上
[root@harbor /opt/kubernetes/cfg]# for instance in master01 master02 ; do
  scp admin.kubeconfig kube-controller-manager.kubeconfig kube-scheduler.kubeconfig ${instance}:/opt/kubernetes/cfg/
done
admin.kubeconfig                        100% 6195     3.5MB/s   00:00    
kube-controller-manager.kubeconfig      100% 6321     2.4MB/s   00:00    
kube-scheduler.kubeconfig               100% 6271     2.0MB/s   00:00    
admin.kubeconfig                        100% 6195     2.3MB/s   00:00    
kube-controller-manager.kubeconfig      100% 6321     2.7MB/s   00:00    
kube-scheduler.kubeconfig               100% 6271     3.1MB/s   00:00    


```





## 部署etcd

```BASH
[root@harbor /server/soft]# tar xf etcd-v3.5.0-linux-amd64.tar.gz 

[root@harbor /server/soft]# for host in master01 master02 node01 ;do scp etcd-v3.5.0-linux-amd64/etcd* $host:/usr/local/bin/;done

{ # master01 master02 node01 
[root@master01 ~]# mkdir -p /var/lib/etcd && chmod 700 /var/lib/etcd
[root@master01 ~]# ll -d /var/lib/etcd/
drwx------ 2 root root 6 Jun 26 21:22 /var/lib/etcd/

INTERNAL_IP=$(hostname -i)

[root@master01 ~]# cat <<EOF | tee /etc/systemd/system/etcd.service
[Unit]
Description=ETCD Server
Documentation=https://github.com/coreos
After=network.target
After=network-online.target
Wants=network-online.target
[Service]
Type=notify
ExecStart=/usr/local/bin/etcd \\
  --name etcd0 \\
  --cert-file=/opt/etcd/ssl/kubernetes.pem \\
  --key-file=/opt/etcd/ssl/kubernetes-key.pem \\
  --peer-cert-file=/opt/etcd/ssl/kubernetes.pem \\
  --peer-key-file=/opt/etcd/ssl/kubernetes-key.pem \\
  --trusted-ca-file=/opt/etcd/ssl/ca.pem \\
  --peer-trusted-ca-file=/opt/etcd/ssl/ca.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-client-urls https://${INTERNAL_IP}:2379 \\
  --advertise-client-urls https://${INTERNAL_IP}:2379 \\
  --initial-cluster-token etcd-cluster-0 \\
  --initial-cluster etcd0=https://172.16.0.160:2380,etcd1=https://172.16.0.161:2380,etcd2=https://172.16.0.165:2380 \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

#上面的 --name etcd0   每台修改和下面的--initial-cluster 对应

[root@master01 ~]# systemctl daemon-reload && systemctl enable etcd && systemctl start etcd
[root@master01 ~]# for host in master01 master02 node01 ;do ssh $host systemctl status etcd | grep Active ;done
   Active: active (running) since Sat 2021-06-26 21:56:28 CST; 3min 2s ago
   Active: active (running) since Sat 2021-06-26 21:56:28 CST; 3min 2s ago
   Active: active (running) since Sat 2021-06-26 21:56:30 CST; 3min 1s ago
}

#验证
[root@master01 ~]# ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://172.16.0.160:2379 \
  --cacert=/opt/etcd/ssl/ca.pem \
  --cert=/opt/etcd/ssl/kubernetes.pem \
  --key=/opt/etcd/ssl/kubernetes-key.pem
  #结果
7b90df20054c2af, started, master02, https://172.16.0.161:2380, https://172.16.0.161:2379, false
114bc58bd2c1e992, started, node01, https://172.16.0.165:2380, https://172.16.0.165:2379, false
ff3cce47b1cba540, started, master01, https://172.16.0.160:2380, https://172.16.0.160:2379, false

[root@master01 ~]# ETCDCTL_API=3 etcdctl --cacert=/opt/etcd/ssl/ca.pem --cert=/opt/etcd/ssl/kubernetes.pem --key=/opt/etcd/ssl/kubernetes-key.pem --endpoints="https://172.16.0.160:2379,https://172.16.0.161:2379,https://172.16.0.165:2379" endpoint health --write-out=table
+---------------------------+--------+-------------+-------+
|         ENDPOINT          | HEALTH |    TOOK     | ERROR |
+---------------------------+--------+-------------+-------+
| https://172.16.0.161:2379 |   true |  9.342897ms |       |
| https://172.16.0.160:2379 |   true | 10.260971ms |       |
| https://172.16.0.165:2379 |   true | 11.061864ms |       |
+---------------------------+--------+-------------+-------+

[root@master01 ~]# ETCDCTL_API=3 etcdctl --cacert=/opt/etcd/ssl/ca.pem --cert=/opt/etcd/ssl/kubernetes.pem --key=/opt/etcd/ssl/kubernetes-key.pem --endpoints="https://172.16.0.160:2379,https://172.16.0.161:2379,https://172.16.0.165:2379" endpoint health 
https://172.16.0.160:2379 is healthy: successfully committed proposal: took = 10.86439ms
https://172.16.0.161:2379 is healthy: successfully committed proposal: took = 11.164205ms
https://172.16.0.165:2379 is healthy: successfully committed proposal: took = 13.269171ms
```

## 部署apiserver

```bash
{
[root@master01 ~]# tree /opt/kubernetes/  #目录已经规划好了
/opt/kubernetes/
├── cfg
├── log
└── ssl
    ├── ca-key.pem
    ├── ca.pem
    ├── kubernetes-key.pem
    ├── kubernetes.pem
    ├── master01-key.pem
    ├── master01.pem
    ├── service-account-key.pem
    └── service-account.pem
}
```

使用节点的内网 IP 地址作为 API server 与集群内部成员的广播地址

```BASH
#解压分发文件
[root@harbor /server/soft]# tar xf kubernetes-server-linux-amd64.tar.gz 
[root@harbor /server/soft]# cd kubernetes/server/bin/
[root@harbor /server/soft/kubernetes/server/bin]# for host in master01 master02;do scp kube-apiserver kube-scheduler kube-controller-manager $host:/usr/local/bin/ ;done
kube-apiserver                           100%  116MB 116.4MB/s   00:01    
kube-scheduler                           100%   45MB 111.4MB/s   00:00    
kube-controller-manager                  100%  111MB 114.5MB/s   00:00    
kube-apiserver                           100%  116MB 112.1MB/s   00:01    
kube-scheduler                           100%   45MB 113.5MB/s   00:00    
kube-controller-manager                  100%  111MB 117.6MB/s   00:00    
[root@harbor /server/soft/kubernetes/server/bin]# for host in master01 master02;do scp kubectl kubeadm $host:/usr/bin/ ;done
kubectl                                  100%   44MB  94.5MB/s   00:00    
kubeadm                                  100%   43MB 112.8MB/s   00:00    
kubectl                                  100%   44MB  84.5MB/s   00:00    
kubeadm                                  100%   43MB 117.7MB/s   00:00     
    
#获取IP地址
INTERNAL_IP=$(hostname -i)
#生成kube-apiserver。service systemd文件
cat <<EOF |tee /etc/systemd/system/kube-apiserver.service
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=${INTERNAL_IP} \\
  --allow-privileged=true \\
  --apiserver-count=2 \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/opt/kubernetes/log/audit.log \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --client-ca-file=/opt/kubernetes/ssl/ca.pem \\
  --enable-admission-plugins=NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --etcd-cafile=/opt/kubernetes/ssl/ca.pem \\
  --etcd-certfile=/opt/kubernetes/ssl/kubernetes.pem \\
  --etcd-keyfile=/opt/kubernetes/ssl/kubernetes-key.pem \\
  --etcd-servers=https://172.16.0.160:2379,https://172.16.0.161:2379,https://172.16.0.165:2379 \\
  --event-ttl=1h \\
  --encryption-provider-config=/opt/kubernetes/cfg/encryption-config.yaml \\
  --kubelet-certificate-authority=/opt/kubernetes/ssl/ca.pem \\
  --kubelet-client-certificate=/opt/kubernetes/ssl/kubernetes.pem \\
  --kubelet-client-key=/opt/kubernetes/ssl/kubernetes-key.pem \\
  --kubelet-https=true \\
  --service-account-issuer=api \\
  --service-account-key-file=/opt/kubernetes/ssl/service-account.pem \\
  --service-account-signing-key-file=/opt/kubernetes/ssl/service-account-key.pem \\
  --service-cluster-ip-range=10.0.0.0/24 \\
  --service-node-port-range=30000-32767 \\
  --tls-cert-file=/opt/kubernetes/ssl/kubernetes.pem \\
  --tls-private-key-file=/opt/kubernetes/ssl/kubernetes-key.pem \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
#  --apiserver-count=2 集群中apiserver 数量2 必须大于等于2
1.20以后必须加的参数
#  --service-account-issuer=api \\
#  --service-account-key-file=/opt/kubernetes/ssl/service-account.pem \\
#  --service-account-signing-key-file=/opt/kubernetes/ssl/service-account-key.pem \\

[root@master01 ~]# systemctl daemon-reload && systemctl start kube-apiserver && systemctl enable kube-apiserver
[root@master01 ~]# systemctl status kube-apiserver|grep Active

```

## 部署kube-controller-manager

```BASH
#生成 kube-controller-manager.service systemd 配置文件：
#配置生成配置

cat <<EOF | tee /etc/systemd/system/kube-controller-manager.service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \\
  --bind-address=127.0.0.1 \\
  --cluster-cidr=10.244.0.0/16 \\
  --cluster-name=kubernetes \\
  --cluster-signing-cert-file=/opt/kubernetes/ssl/ca.pem \\
  --cluster-signing-key-file=/opt/kubernetes/ssl/ca-key.pem \\
  --kubeconfig=/opt/kubernetes/cfg/kube-controller-manager.kubeconfig \\
  --leader-elect=true \\
  --root-ca-file=/opt/kubernetes/ssl/ca.pem \\
  --service-account-private-key-file=/opt/kubernetes/ssl/service-account-key.pem \\
  --service-cluster-ip-range=10.0.0.0/24 \\
  --use-service-account-credentials=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

```

## 部署kube-scheduler

```BASH
#生成 kube-scheduler.service systemd 配置文件：

cat > /opt/kubernetes/cfg/kube-scheduler.conf << EOF
KUBE_SCHEDULER_OPTS="--logtostderr=false \\
--v=2 \\
--log-dir=/opt/kubernetes/log \\
--leader-elect=true \\
--kubeconfig=/opt/kubernetes/cfg/kube-scheduler.kubeconfig \\
--bind-address=127.0.0.1"
EOF


cat > /etc/systemd/system/kube-scheduler.service << EOF
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
EnvironmentFile=/opt/kubernetes/cfg/kube-scheduler.conf
ExecStart=/usr/local/bin/kube-scheduler \$KUBE_SCHEDULER_OPTS
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

[root@master01 ~]# systemctl daemon-reload && systemctl start kube-scheduler && systemctl enable kube-scheduler
[root@master01 ~]# systemctl status kube-scheduler|grep Active
```

启动上面服务

```BASH
[root@master01 /opt/kubernetes/ssl]# for i in kube-apiserver kube-controller-manager kube-scheduler ;do systemctl daemon-reload ; systemctl enable $i ; systemctl start $i ;done

[root@master01 /opt/kubernetes/ssl]# for host in master01 master02;do ssh $host systemctl status kube-apiserver kube-controller-manager kube-scheduler|grep Active ;echo "+---------------------------+ $host +-------------------------------+";done
```

### 服务检查

```BASH
#apiserver 检查
for host in master01 master02;do for i in kube-apiserver kube-controller-manager kube-scheduler;
do  echo "+-------------------------------------------------------+";echo -e "    $host  $i is : \c" && ssh $host systemctl status $i|grep Active |awk -F"[()]" '{print $2}'  ; echo "+-------------------------------------------------------+";done;done

#etcd检查
for host in master01 master02 node01;do 
echo "+---------------------------------------------+";echo -e "    $host  etcd is  |  \c" && ssh $host systemctl status etcd|grep Active |awk -F"[()]" '{print $2}' ;echo "+---------------------------------------------+";done

#kubelet,proxy检查
for host in master01 master02 node01 node02 harbor;do for i in kube-proxy kubelet;
do  echo "+-------------------------------------------------------+";echo -e "    $host  $i is : \c" && ssh $host systemctl status $i|grep Active |awk -F"[()]" '{print $2}'  ; echo "+-------------------------------------------------------+";done;done
```

### 健康检查

```BASH
#创建一个amdin缓存目录
[root@master01 ~]# mkdir -p /root/.kube
[root@master01 ~]# cp /opt/kubernetes/cfg/admin.kubeconfig /root/.kube/config
[root@master01 ~]# kubectl get cs
Warning: v1 ComponentStatus is deprecated in v1.19+
NAME                 STATUS    MESSAGE                         ERROR
controller-manager   Healthy   ok                              
scheduler            Healthy   ok                              
etcd-1               Healthy   {"health":"true","reason":""}   
etcd-2               Healthy   {"health":"true","reason":""}   
etcd-0               Healthy   {"health":"true","reason":""}   

[root@master02 ~]#  mkdir -p /root/.kube
[root@master02 ~]# cp /opt/kubernetes/cfg/admin.kubeconfig /root/.kube/config
[root@master02 ~]# kubectl get cs
Warning: v1 ComponentStatus is deprecated in v1.19+
NAME                 STATUS    MESSAGE                         ERROR
controller-manager   Healthy   ok                              
scheduler            Healthy   ok                              
etcd-1               Healthy   {"health":"true","reason":""}   
etcd-0               Healthy   {"health":"true","reason":""}   
etcd-2               Healthy   {"health":"true","reason":""}   

PS:
#如果上面没有mkdir .kube 且移动admin.kubeconfig使用这个格式
kubectl get nodes --kubeconfig /opt/kubernetes/cfg/admin.kubeconfig
```

### 验证apiserver

```BASH
[root@master01 ~]# curl --cacert /opt/kubernetes/ssl/ca.pem https://172.16.0.160:6443/version
{
  "major": "1",
  "minor": "21",
  "gitVersion": "v1.21.2",
  "gitCommit": "092fbfbf53427de67cac1e9fa54aaa09a28371d7",
  "gitTreeState": "clean",
  "buildDate": "2021-06-16T12:53:14Z",
  "goVersion": "go1.16.5",
  "compiler": "gc",
  "platform": "linux/amd64"

```

## kubelet PBAC授权

配置 API Server 访问 Kubelet API 的 RBAC 授权。访问 Kubelet API 是获取 metrics、日志以及执行容器命令所必需的。

这里设置 Kubeket `--authorization-mode` 为 `Webhook` 模式。Webhook 模式使用 [SubjectAccessReview](https://kubernetes.io/docs/admin/authorization/#checking-api-access) API 来决定授权。

创建 `system:kube-apiserver-to-kubelet` [ClusterRole](https://kubernetes.io/docs/admin/authorization/rbac/#role-and-clusterrole) 以允许请求 Kubelet API 和执行许用来管理 Pods 的任务:

```BASH
cat <<EOF | kubectl apply --kubeconfig admin.kubeconfig -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:kube-apiserver-to-kubelet
rules:
  - apiGroups:
      - ""
    resources:
      - nodes/proxy
      - nodes/stats
      - nodes/log
      - nodes/spec
      - nodes/metrics
    verbs:
      - "*"
EOF
```

Kubernetes API Server 使用客户端凭证授权 Kubelet 为 `kubernetes` 用户，此凭证用 `--kubelet-client-certificate` flag 来定义。

绑定 `system:kube-apiserver-to-kubelet` ClusterRole 到 `kubernetes` 用户:

```BASH
cat <<EOF | kubectl apply --kubeconfig admin.kubeconfig -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: system:kube-apiserver
  namespace: ""
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kube-apiserver-to-kubelet
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: kubernetes
EOF
```

### kubernetes 前端LB







## 部署计算节点

### kubelet

```BASH
[root@harbor /server/soft/kubernetes/server/bin]# for i in `cat /root/host.txt`;do scp kubectl kubelet kube-proxy $i:/usr/local/bin/;done
kubectl                                 100%   44MB 129.4MB/s   00:00    
kubelet                                 100%  113MB  81.1MB/s   00:01    
kube-proxy                              100%   41MB  69.0MB/s   00:00    
kubectl                                 100%   44MB 115.4MB/s   00:00    
kubelet                                 100%  113MB 112.7MB/s   00:01    
kube-proxy                              100%   41MB 112.7MB/s   00:00    
kubectl                                 100%   44MB  93.7MB/s   00:00    
kubelet                                 100%  113MB 112.8MB/s   00:00    
kube-proxy                              100%   41MB  97.3MB/s   00:00    
kubectl                                 100%   44MB  59.8MB/s   00:00    
kubelet                                 100%  113MB 116.1MB/s   00:00    
kube-proxy                              100%   41MB 104.8MB/s   00:00    
kubectl                                 100%   44MB  81.2MB/s   00:00    
kubelet                                 100%  113MB  80.9MB/s   00:01    
kube-proxy                              100%   41MB  74.9MB/s   00:00    

{
[root@master01 ~]# kubelet --version
Kubernetes v1.21.2
[root@master01 ~]# kube-proxy --version
Kubernetes v1.21.2


# The resolvConf configuration is used to avoid loops when using CoreDNS for service discovery on systems running systemd-resolved.
cat <<EOF | tee /opt/kubernetes/cfg/kubelet-config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/opt/kubernetes/ssl/ca.pem"
authorization:
  mode: Webhook
clusterDomain: "cluster.local"
clusterDNS:
  - "10.0.0.2"
resolvConf: "/run/systemd/resolve/resolv.conf"
runtimeRequestTimeout: "15m"
tlsCertFile: "/opt/kubernetes/ssl/${HOSTNAME}.pem"
tlsPrivateKeyFile: "/opt/kubernetes/ssl/${HOSTNAME}-key.pem"
EOF


{
#all 
[root@master01 ~]# mv /opt/kubernetes/cfg/$(hostname).kubeconfig /opt/kubernetes/cfg/kubelet-kubeconfig
}

cat <<EOF | tee /etc/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=docker.service
Requires=docker.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --config=/opt/kubernetes/cfg/kubelet-config.yaml \\
  --kubeconfig=/opt/kubernetes/cfg/kubelet-kubeconfig \\
  --network-plugin=cni \\
  --register-node=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

[root@master01 ~]# systemctl daemon-reload && systemctl start kubelet && systemctl enable kubelet

[root@master01 ~]# echo -e "$(hostname) kubelet service is : \c" && systemctl status kubelet|grep Active|awk -F"[()]" '{print $2}'|grep "running"
master01 kubelet service is : running

}


######################################################


kubelet 示例
/usr/bin/kubelet \
  --bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf \
  --kubeconfig=/etc/kubernetes/kubelet.conf \
  --pod-manifest-path=/etc/kubernetes/manifests \
  --allow-privileged=true \
  --network-plugin=cni \
  --cni-conf-dir=/etc/cni/net.d \
  --cni-bin-dir=/opt/cni/bin \
  --cluster-dns=10.96.0.10 \
  --cluster-domain=cluster.local \
  --authorization-mode=Webhook \
  --client-ca-file=/etc/kubernetes/pki/ca.crt \
  --cadvisor-port=0 \
  --rotate-certificates=true \
  --cert-dir=/var/lib/kubelet/pki

```

### kube-proxy

```BASH
{
/opt/kubernetes/cfg/kube-proxy.kubeconfig   #此文件上面已经放到该目录

cat <<EOF | tee /opt/kubernetes/cfg/kube-proxy-config.yaml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: "/opt/kubernetes/cfg/kube-proxy.kubeconfig"
hostnameOverride: ${hostname}
clusterCIDR: "10.244.0.0/16"
EOF

cat <<EOF | sudo tee /etc/systemd/system/kube-proxy.service
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --config=/opt/kubernetes/cfg/kube-proxy-config.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

[root@master01 ~]# systemctl daemon-reload && systemctl start kube-proxy && systemctl enable kube-proxy
[root@master01 ~]# echo -e "$(hostname) kubelet service is : \c" && systemctl status kubelet|grep Active|awk -F"[()]" '{print $2}'|grep "running"
master01 kubelet service is : running
}

```

### 计算端检查服务

```BASH
#检查服务
for host in master01 master02 node01 node02 harbor;do for i in kube-proxy kubelet;
do  echo "+-------------------------------------------------------+";echo -e "    $host  $i is : \c" && ssh $host systemctl status $i|grep Active |awk -F"[()]" '{print $2}'  ; echo "+-------------------------------------------------------+";done;done
```

PS：

```BASH
#如果上面没有mkdir .kube 且移动admin.kubeconfig使用这个格式
kubectl get nodes --kubeconfig /opt/kubernetes/cfg/admin.kubeconfig
```

### 验证服务

```BASH
[root@master01 ~]# kubectl get node 
NAME       STATUS     ROLES    AGE   VERSION
harbor     NotReady   <none>   18m   v1.21.2
master01   NotReady   <none>   29m   v1.21.2
master02   NotReady   <none>   18m   v1.21.2
node01     NotReady   <none>   18m   v1.21.2
node02     NotReady   <none>   18m   v1.21.2
```

### port-forward

```bash
[root@master01 /opt/kubernetes/yaml]# kubectl port-forward --help
Forward one or more local ports to a pod. This command requires the node to have 'socat' installed.

 Use resource type/name such as deployment/mydeployment to select a pod. Resource type defaults to 'pod' if omitted.

 If there are multiple pods matching the criteria, a pod will be selected automatically. The forwarding session ends
when the selected pod terminates, and rerun of the command is needed to resume forwarding.

Examples:
  # Listen on ports 5000 and 6000 locally, forwarding data to/from ports 5000 and 6000 in the pod
  kubectl port-forward pod/mypod 5000 6000
  
  # Listen on ports 5000 and 6000 locally, forwarding data to/from ports 5000 and 6000 in a pod selected by the
deployment
  kubectl port-forward deployment/mydeployment 5000 6000
  
  # Listen on port 8443 locally, forwarding to the targetPort of the service's port named "https" in a pod selected by
the service
  kubectl port-forward service/myservice 8443:https
  
  # Listen on port 8888 locally, forwarding to 5000 in the pod
  kubectl port-forward pod/mypod 8888:5000
  
  # Listen on port 8888 on all addresses, forwarding to 5000 in the pod
  kubectl port-forward --address 0.0.0.0 pod/mypod 8888:5000
  
  # Listen on port 8888 on localhost and selected IP, forwarding to 5000 in the pod
  kubectl port-forward --address localhost,10.19.21.23 pod/mypod 8888:5000
  
  # Listen on a random port locally, forwarding to 5000 in the pod
  kubectl port-forward pod/mypod :5000

Options:
      --address=[localhost]: Addresses to listen on (comma separated). Only accepts IP addresses or localhost as a
value. When localhost is supplied, kubectl will try to bind on both 127.0.0.1 and ::1 and will fail if neither of these
addresses are available to bind.
      --pod-running-timeout=1m0s: The length of time (like 5s, 2m, or 3h, higher than zero) to wait until at least one
pod is running

Usage:
  kubectl port-forward TYPE/NAME [options] [LOCAL_PORT:]REMOTE_PORT [...[LOCAL_PORT_N:]REMOTE_PORT_N]

Use "kubectl options" for a list of global command-line options (applies to all commands).

```



```bash
#kubectl port-forward需要的组件
[root@master01 /opt/kubernetes/yaml]# yum install -y socat conntrack-tools

cni-plugins-linux
#下载：https://github.com/containernetworking/plugins/releases/
wget https://github.com/containernetworking/plugins/releases/download/v0.9.1/cni-plugins-linux-amd64-v0.9.1.tgz
[root@master01 /server/soft]# mkdir -p /opt/cni/bin 
[root@master01 /server/soft]# tar xf cni-plugins-linux-amd64-v0.9.1.tgz -C /opt/cni/bin/

```

### CNI

https://github.com/containernetworking/cni/blob/spec-v0.4.0/SPEC.md

https://github.com/containernetworking/cni 配置文件

```BASH
参数：

cniVersion（字符串）：   此配置符合的 CNI 规范的语义版本。
name（字符串）：网络名称。这在主机（或其他管理域）上的所有容器中应该是唯一的。
type （字符串）：指的是 CNI 插件可执行文件的文件名。
args（字典，可选）：容器运行时提供的附加参数。例如，可以通过将标签字典添加到 下的标签字段来将标签字典传                    递给 CNI 插件args。
ipMasq（布尔值，可选）：如果插件支持，则在主机上为此网络设置 IP 伪装。如果主机将充当无法路由到分配给容                    器的 IP 的子网的网关，则这是必要的。
ipam （字典，可选）：具有 IPAM 特定值的字典：
type （字符串）：指的是 IPAM 插件可执行文件的文件名。
dns （字典，可选）：具有 DNS 特定值的字典：
nameservers（字符串列表，可选）：该网络知道的 DNS 名称服务器的优先级排序列表。列表中的每个条目都是一个                               包含 IPv4 或 IPv6 地址的字符串。
domain （字符串，可选）：用于短主机名查找的本地域。
search（字符串列表，可选）：用于短主机名查找的优先排序搜索域列表。domain大多数解析器会优先考虑。
options （字符串列表，可选）：可以传递给解析器的选项列表

main：
     bridge：创建一个网桥，向其中添加主机和容器。
     ipvlan:在容器中添加一个ipvlan接口。
     loopback：设置loopback接口状态为up。
     macvlan：创建一个新的 MAC 地址，将所有流量转发到容器。
     ptp: 创建一个 veth 对。
     vlan：分配一个vlan设备。
     host-device：将已存在的设备移动到容器中。
Windows：特定于 Windows
     win-bridge：创建一个网桥，向其中添加主机和容器。
     win-overlay：创建容器的覆盖界面。
IPAM：IP地址分配
     dhcp: 在主机上运行守护进程以代表容器发出 DHCP 请求
     host-local: 维护分配 IP 的本地数据库
     static：为容器分配一个静态 IPv4/IPv6 地址，这在调试时很有用。
meta：其他插件
      flannel: 生成一个flannel配置文件对应的接口
      tuning：调整现有接口的 sysctl 参数
      portmap：一个基于 iptables 的端口映射插件。将端口从主机地址空间映射到容器。
      bandwidth：允许通过使用流量控制 tbf（入口/出口）来限制带宽。
      sbr：一个插件，用于为接口（它被链接）配置基于源的路由。
      firewall：一个防火墙插件，它使用 iptables 或 firewalld 添加规则以允许进出容器的流量。

[root@master01 ~]# mkdir -p /etc/cni/net.d
[root@master01 ~]# cat <<EOF | sudo tee /etc/cni/net.d/10-bridge.conf
{
    "cniVersion": "0.4.0",
    "name": "bridge",
    "type": "bridge",
    "bridge": "cni0",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "ranges": [
          ["subnet": "10.0.0.0/16"]
        ],
        "routes": [{"dst": "0.0.0.0/0"}]
    }
}
EOF
#生成 loopback 网络插件配置文件
cat <<EOF | sudo tee /etc/cni/net.d/99-loopback.conf
{
    "cniVersion": "0.4.0",
    "name": "lo",
    "type": "loopback"
}
EOF
```







## 部署网络

### calico

```BASH
[root@master01 ~]# file="/opt/kubernetes/yaml"
[root@master01 ~]# mkdir -p $file && cd $file
```

https://docs.projectcalico.org/archive/v3.18/release-notes/

Calico 作为 CNI 插件安装。必须通过传递`--network-plugin=cni`参数将 kubelet 配置为使用 CNI 网络。（在 kubeadm 上，这是默认设置。）

#### Calico 支持以下 kube-proxy 模式：

`*iptables` （默认）*

*`ipvs`需要 Kubernetes >=v1.9.3。 在 Kubernetes 中启用 IPVS*

#### IP池配置

为 pod IP 地址选择的 IP 范围不能与网络中的任何其他 IP 范围重叠，包括：

*Kubernetes 服务集群 IP 范围*

*分配主机 IP 的范围*

内核依赖

```BASH
ip_set
ip_tables （对于 IPv4）
ip6_tables （对于 IPv6）
ipt_REJECT
ipt_rpfilter
ipt_set
nf_conntrack_netlink 子系统
nf_conntrack_proto_sctp
sctp
xt_addrtype
xt_comment
xt_conntrack
xt_icmp （对于 IPv4）
xt_icmp6 （对于 IPv6）
xt_ipvs,ipt_ipvs
xt_mark
xt_multiport
xt_rpfilter
xt_sctp
xt_set
xt_u32
xt_bpf （对于 eBPF）
vfio-pci
ipip （如果在 IPIP 模式下使用 Calico 网络）
wireguard （如果使用 WireGuard 加密）
```

要更改用于 Pod 的默认 IP 范围，请修改清单的`CALICO_IPV4POOL_CIDR` 部分`calico.yaml`

配置calico:https://docs.projectcalico.org/reference/node/configuration

```BASH
#少于50个节点
[root@master01 /opt/kubernetes/yaml]# curl https://docs.projectcalico.org/manifests/calico.yaml -O
[root@master01 /opt/kubernetes/yaml]# kubectl apply -f calico.yaml
[root@master01 /opt/kubernetes/yaml]# kubectl delete -f calico.yaml
#使用ETCD存储
curl https://docs.projectcalico.org/manifests/calico-etcd.yaml -o calico.yaml
在ConfigMap命名中calico-config，将 的值设置为etcd_endpointsetcd 服务器的 IP 地址和端口。
提示：您可以etcd_endpoint使用逗号作为分隔符指定多个。
kubectl apply -f calico.yaml
自定义：https://docs.projectcalico.org/getting-started/kubernetes/installation/config-options
```

这里因为节点有污点不能创建

```BASH
[root@master01 /opt/kubernetes/yaml]# for i in master01 master02 node01 node02 harbor;do kubectl describe nodes $i |grep Taints;done
Taints:             node.kubernetes.io/not-ready:NoSchedule
Taints:             node.kubernetes.io/not-ready:NoSchedule
Taints:             node.kubernetes.io/not-ready:NoSchedule
Taints:             node.kubernetes.io/not-ready:NoSchedule
Taints:             node.kubernetes.io/not-ready:NoSchedule

calico.yaml
里面改成容忍该污点

       tolerations:                                                                                                                                                    
3529         # Make sure calico-node gets scheduled on all nodes.
3530         - effect: NoSchedule
3531           operator: Exists
3532         # Mark the pod as a critical add-on for rescheduling.
3533 #  - key: CriticalAddonsOnly
3534         - key: node.kubernetes.io/not-ready
3535           operator: Exists
3536         - effect: NoSchedule
3537           operator: Exists

      tolerations:                                                                                                                                                    
3825         # Mark the pod as a critical add-on for rescheduling.
3826         - key: CriticalAddonsOnly
3827           operator: Exists
3828 # - key: node-role.kubernetes.io/master
3829         - key: node.kubernetes.io/not-ready
3830           effect: NoSchedule

```

```BASH
network is not ready: container runtime network not ready: NetworkReady=false reason:NetworkPluginNotReady message:docker: network plugin is not ready: cni config uninitialized
```



```BASH
  # and CNI network config file on each node.
3573         - name: install-cni
3574           image: docker.io/calico/cni:v3.19.1
3575           command: ["/opt/cni/bin/install"]

```





### 安装CNI

Kubernetes 使用容器网络接口 (CNI) 与 Calico 等网络提供商进行交互。向 Kubernetes 提供此 API 的 Calico 二进制文件称为**CNI 插件**，必须安装在 Kubernetes 集群中的每个节点上。

官网：https://docs.projectcalico.org/archive/v3.18/release-notes/

install CNI plugin：https://docs.projectcalico.org/archive/v3.19/getting-started/kubernetes/hardway/install-cni-plugin

为插件提供kubernetes用户账户

在kubernetes证书服务器上为CNI创建密钥进行身份验证和证书请求：

```BASH
[root@harbor ~/tls/kubernetes]# cat > calico-csr.json <<EOF
{
  "CN": "calicon-cni",
  "key": {
    "algo": "rsa",
    "size": 4096
  },
  "names": [
    {
      "C": "CN",
      "L": "kunming",
      "O": "system:nodes",
      "OU": "System",
      "ST": "yunnan"
    }
  ]
}
EOF

[root@harbor ~/tls/kubernetes]# cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  calico-csr.json | cfssljson -bare calico
  
[root@harbor ~/tls/kubernetes]# ls calico*
calico.csr  calico-csr.json  calico-key.pem  calico.pem

我们为 CNI 插件创建一个 kubeconfig 文件，用于访问 Kubernetes。
#生成配置文件
#KUBERNETES_IP="https://172.16.0.160:6443"
APISERVER=$(kubectl config view -o jsonpath='{.clusters[0].cluster.server}')
KUBERNETES_CONFIG="/opt/kubernetes/cfg/calico-kubeconfig"

kubectl config set-cluster kubernetes \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=${APISERVER} \
    --kubeconfig=${KUBERNETES_CONFIG}

kubectl config set-credentials calico-cni \
    --client-certificate=calico.pem\
    --client-key=calico-key.pem \
    --embed-certs=true \
    --kubeconfig=${KUBERNETES_CONFIG}

kubectl config set-context default \
    --cluster=kubernetes \
    --user=calico-cni \
    --kubeconfig=${KUBERNETES_CONFIG}

kubectl config use-context default --kubeconfig=${KUBERNETES_CONFIG}

#复制生成的kubeconfig文件分发到集群中的每个节点
[root@harbor ~/tls/kubernetes]# cat /opt/kubernetes/cfg/calico-cni.kubeconfig 
[root@harbor ~/tls/kubernetes]# for i in `cat /root/host.txt`;do scp /opt/kubernetes/cfg/calico-cni.kubeconfig  $i:/opt/kubernetes/cfg/;done
calico-cni.kubeconfig              100% 8772     6.7MB/s   00:00    
calico-cni.kubeconfig              100% 8772     6.6MB/s   00:00    
calico-cni.kubeconfig              100% 8772     4.8MB/s   00:00    
calico-cni.kubeconfig              100% 8772     8.1MB/s   00:00    
calico-cni.kubeconfig              100% 8772    12.8MB/s   00:00    

#提供RBAC
定义 CNI 插件将用于访问 Kubernetes 的集群角色
[root@master01 /server/soft]# kubectl apply -f - <<EOF
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: calico-cni
rules:
  # The CNI plugin needs to get pods, nodes, and namespaces.
  - apiGroups: [""]
    resources:
      - pods
      - nodes
      - namespaces
    verbs:
      - get
  # The CNI plugin patches pods/status.
  - apiGroups: [""]
    resources:
      - pods/status
    verbs:
      - patch
 # These permissions are required for Calico CNI to perform IPAM allocations.
  - apiGroups: ["crd.projectcalico.org"]
    resources:
      - blockaffinities
      - ipamblocks
      - ipamhandles
    verbs:
      - get
      - list
      - create
      - update
      - delete
  - apiGroups: ["crd.projectcalico.org"]
    resources:
      - ipamconfigs
      - clusterinformations
      - ippools
    verbs:
      - get
      - list
EOF
#clusterrole.rbac.authorization.k8s.io/calico-cni created

将集群角色绑定到calico-cni账户。
[root@master01 /server/soft]# kubectl create clusterrolebinding calico-cni --clusterrole=calico-cni --user=calico-cni

#clusterrolebinding.rbac.authorization.k8s.io/calico-cni created

安装插件 
{
#all
[root@master01 /server/soft]# wget https://github.com/projectcalico/cni-plugin/releases/download/v3.18.4/calico-ipam-amd64

[root@master01 /server/soft]# wget https://github.com/projectcalico/cni-plugin/releases/download/v3.18.4/calico-amd64
[root@master01 /server/soft]# chmod +x calico-*
[root@master01 /server/soft]# ll
-rwxr-xr-x 1 root root 36564992 May 26 03:30 calico-amd64
-rwxr-xr-x 1 root root 36564992 May 26 03:30 calico-ipam-amd64
[root@master01 /server/soft]# mkdir -p /opt/cni/bin
[root@master01 /server/soft]# mv calico-amd64 /opt/cni/bin/calico
[root@master01 /server/soft]# mv calico-ipam-amd64 /opt/cni/bin/calico-ipam


[root@master01 /server/soft]# mkdir -p /etc/cni/net.d/
[root@master01 /server/soft]# cp /opt/kubernetes/cfg/calico-cni.kubeconfig /etc/cni/net.d/ && chmod 600 /etc/cni/net.d/calico-cni.kubeconfig
[root@master01 /server/soft]# ll /etc/cni/net.d
-rw------- 1 root root 8772 Jun 28 14:44 calico-cni.kubeconfig
[root@master01 /opt/cni/bin]# for i in master02 node01 node02 harbor ;do ssh $i mkdir -p /opt/cni/bin ;scp /opt/cni/bin/calico* $i:/opt/cni/bin/;done
calico                              100%   35MB  82.7MB/s   00:00    
calico-ipam                         100%   35MB 109.3MB/s   00:00    
calico                              100%   35MB  95.5MB/s   00:00    
calico-ipam                         100%   35MB 106.4MB/s   00:00    
calico                              100%   35MB  91.4MB/s   00:00    
calico-ipam                         100%   35MB 106.4MB/s   00:00    
calico                              100%   35MB 103.2MB/s   00:00    
calico-ipam                         100%   35MB 112.4MB/s   00:00    


#编写CNI配置
cat > /etc/cni/net.d/10-calico.conflist <<EOF
{
  "name": "k8s-pod-network",
  "cniVersion": "0.4.0",
  "plugins": [
    {
      "type": "calico",
      "log_level": "info",
      "datastore_type": "kubernetes",
      "mtu": 1500,
      "ipam": {
          "type": "calico-ipam"
      },
      "policy": {
          "type": "k8s"
      },
      "kubernetes": {
          "kubeconfig": "/etc/cni/net.d/calico-cni.kubeconfig"
      }
    },
    {
      "type": "portmap",
      "snat": true,
      "capabilities": {"portMappings": true}
    }
  ]
}
EOF



}
```

kubeadm init --pod-network-cidr=10.244.0.0/16 --kubernetes-version=v1.21.2

