#!/bin/bash
#----------------------------------------------
# Author        : 349925756
# Email         : 349925756@qq.com
# Last modified : 2021-06-08 21:31
# Filename      : uuid.sh
# Description   : 
# Version       : 1.1 
#----------------------------------------------
#修改网卡UUID IP地址 主机名，关闭防火墙，selinux 安装常用工具关闭swap 导入kubectl tab补全
#uuid  ip
path_eth0="/etc/sysconfig/network-scripts/ifcfg-eth0"
sed -i "/UUID/c UUID=$(uuidgen)" $path_eth0   
sed -i "s/$1/$2/g" $path_eth0
echo "$3" >/etc/hostname
systemctl stop firewalld && systemctl disable firewalld
sed -i "s/SELINUX=.*/SELINUX=disabled/g" /etc/selinux/config
\cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime 
systemctl enable chronyd
sed -ri 's/.*swap.*/#&/' /etc/fstab 
reboot

