#!/bin/bash
echo "Nginx keepalived_Check......"
#nginx,keepalived检查
echo "+-------------------------------------------------------+";
for host in master{01..03};do for i in nginx keepalived;
do echo -e "    $host  $i is : \c" && ssh $host systemctl status $i|grep Active |awk -F"[()]" '{print $2}' ;done;done
echo "+-------------------------------------------------------+";


echo "Kuoe-apiserver_Check......"
#apiserver 检查
echo "+-------------------------------------------------------+";
for host in master{01..03};do for i in kube-apiserver kube-controller-manager kube-scheduler;
do echo -e "    $host  $i is : \c" && ssh $host systemctl status $i|grep Active |awk -F"[()]" '{print $2}' ;done;done
echo "+-------------------------------------------------------+";


echo "Etcd_Check......"
echo "+-------------------------------------------------------+";
#etcd检查
for host in master{01..03};do echo -e "    $host  etcd is  |  \c" && ssh $host systemctl status etcd|grep Active |awk -F"[()]" '{print $2}' ;done
echo "+-------------------------------------------------------+";

echo "Docker_Check......"
echo "+-------------------------------------------------------+";
#docker检查
for host in master{01..03} node{01,02};do echo -e "    $host  docker is  |  \c" && ssh $host systemctl status docker|grep Active |awk -F"[()]" '{print $2}' ;done
echo "+-------------------------------------------------------+";


echo "Kube-proxy kubelet_Check......"
#kubelet,proxy检查
echo "+-------------------------------------------------------+";
for host in master{01..03} node{01,02};do for i in kube-proxy kubelet;
do echo -e "    $host  $i is : \c" && ssh $host systemctl status $i|grep Active |awk -F"[()]" '{print $2}' ;done;done
echo "+-------------------------------------------------------+";          
