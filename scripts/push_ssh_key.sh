#!/bin/bash
#yum install sshpass -y
for h in master{01..03} node{01,02}
do
  echo "---------------------------HostName: $h  Pub-Key start ------------------------------" 
  sshpass -p******* ssh-copy-id -i  /root/.ssh/id_rsa.pub $h "-o StrictHostKeyChecking=no"
  echo -e "HostName	: $h Send Successfull" 
  echo "---------------------------HostName: $h  Pub-Key end ------------------------------"
  echo -e " \n" 
done
