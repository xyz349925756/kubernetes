#/bin/bash
One_Image=(
  kube-apiserver:v1.29.4 
  kube-controller-manager:v1.29.4
  kube-scheduler:v1.29.4
  kube-proxy:v1.29.4
  etcd:3.5.12-0
  pause:3.9
)

Two_Image=(
  metrics-server:v0.7.1
  coredns:v1.11.1
)

Three_Image=(
  ingress-nginx-controller:v1.0.5
  ingress-nginx-kube-webhook-certgen:v1.1.1
)

for imagename in ${One_Image[@]};
do 
  docker pull docker.io/xyz349925756/${imagename}
  docker tag docker.io/xyz349925756/${imagename} registry.k8s.io/${imagename}
  docker rmi docker.io/xyz349925756/${imagename}
done

for imagename2 in ${Two_Image[@]};
do 
  docker pull docker.io/xyz349925756/${imagename2}
  docker tag docker.io/xyz349925756/${imagename2} registry.k8s.io/`echo $imagename2|awk -F":" '{print $1}'`/${imagename2}
  docker rmi docker.io/xyz349925756/${imagename2}
done

for imagename3 in ${Three_Image[@]};
do 
  docker pull docker.io/xyz349925756/${imagename3}
  docker tag docker.io/xyz349925756/${imagename3} registry.k8s.io/ingress-nginx/`echo $imagename3|awk -F"nginx-" '{print $2}'`
  docker rmi docker.io/xyz349925756/${imagename3}
done
