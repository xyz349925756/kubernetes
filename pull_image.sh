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
