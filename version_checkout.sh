#!/bin/sh
filedir=(pause coredns ingress-nginx-controller ingress-nginx-kube-webhook-certgen metrics-server)

for i in ${filedir[@]}
do
    touch ${i}/`cat ${i}/Dockerfile |awk -F ':' '{print $NF}'`
done 

