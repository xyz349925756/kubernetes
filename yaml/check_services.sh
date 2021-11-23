#!/bin/bash
services1=(etcd docker kubelet kube-proxy kube-apiserver kube-controller-manager kube-scheduler)
services2=(docker kubelet kube-proxy)
hosts1=(master01)
hosts2=(node01,)

funtion_services() {
   printf  "\033[33m %25s \033[0m  :  " $i && ssh $h systemctl status $i | grep Active |awk -F"[()]" '{print $2}'
}

for h in ${hosts1[@]};
do
    echo -e "\033[41;37m    $h Services Is Checking......\033[0m"
    for i in ${services1[@]};
    do
       funtion_services
    done
done

for n in ${hosts2[@]};
do
    echo -e "\033[44;37m  $n Services Is Checking......\033[0m"
    for i in ${services2[@]};
    do
       funtion_services
    done
done
