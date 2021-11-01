#!/bin/bash
#######################################################################################
# Before run this script, please install the GPU driver with GUI in Software&Updates.
# Usage:
#      sudo ./install_env.sh
#   or run as root:
#      ./install_env.sh     PS.  This script is for Ubuntu 16.04
######################################################################################

BASEDIR=$(dirname "$0")
docker_test=`dpkg -l | grep docker-ce | wc -l`
docker2_test=`dpkg -l | grep nvidia-docker2 | wc -l`

function check_openssh {
   #install ifconfig
   test_ifconfig=`ifconfig`
   if [ $? -ne 0 ]
   then
      sudo apt-get install net-tools -y
	  echo "==============================the package net-tools has been installed successfully!===================================="
   fi 
   echo "check openssh"
   check_ssh=`ps -ef|grep /usr/sbin/sshd|grep -v color|wc -l`
   if [ $check_ssh -eq 0 ]
   then
      echo "===========================================install the openssh-server==================================================="
      sudo apt-get install openssh-server -y
      systemctl enable ssh
      systemctl start ssh
   else
      echo "============================================The service sshd is running!==============================================="
   fi
}

function disable_nouveau {
    #disable the nouveau
	check_nouveau=`lsmod | grep nouveau| wc -l`
	check_blacklist=`cat /etc/modprobe.d/blacklist.conf | grep nouveau | wc -l`
	if [ $check_nouveau -ne 0 -a $check_blacklist -lt 2 ];then 
	##-a replace with "if [ $check_nouveau -eq 0 ] && [ $check_blacklist -lt 2 ]"  / if [[ $check_nouveau -ne 0 && $check_blacklist -lt 2 ]]
	   sudo echo -e "blacklist nouveau\noptions nouveau modeset=0" >> /etc/modprobe.d/blacklist.conf
       sudo update-initramfs -u  
       echo "====================blacklist.conf has been updated,please reboot this server================================================="	   
	else
	   echo "=================Nouveau has been forbiddened,Do not need to do it!==========================================================="
	fi	   
}

function install_common_tools {
    #install common tools google-chrome-stable,workbench,vim,dkms!
	if [ $? -eq 0 ];then
	    echo "===================================begin to install the vim===================================================================="
		sudo apt-get install vim
		echo "===================================begin to install the workbench=============================================================="
		sudo apt-get install mysql-workbench
		echo "===================================begin to install the samba=================================================================="
		sudo apt-get install samba
		echo "===================================begin to install the dkms==================================================================="
		sudo apt-get install dkms
	else 
	    echo "==============Common tools google-chrome-stable,workbench,vim,dkms has been installed successfully!============================="
	fi    
}

function install_docker {
    #instll docker-ce
	if [ $docker_test -eq 0 ]; then
		echo "==================install the docker-ce============================"
		sudo apt-get update
		sudo apt-get -y install apt-transport-https ca-certificates curl software-properties-common
		sudo curl -fsSL http://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | sudo apt-key add  -
		sudo add-apt-repository "deb [arch=amd64] http://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable"
		sudo apt-get -y update
		sudo apt-get -y install docker-ce
		echo "========docker-ce has been installed successfully============="
	else
		echo "============================================the service docker is running!======================================================"
	fi
}

function install_nvidia_docker2 {
    #install nvidia-docker2
	test_docker_daemon=`cat /etc/docker/daemon.json | grep -c registry-mirrors`
    if [ $docker2_test -eq 0 ]; then
		echo "============================================install the nvidia-docker2=========================================================="
		curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | \sudo apt-key add -
		distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
		curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | \sudo tee /etc/apt/sources.list.d/nvidia-docker.list
		sudo apt-get update
		sudo apt-get install -y nvidia-docker2
		echo "the nvidia-docker2 has installed successfully!" 
		if [ $test_docker_daemon -eq 0 ]; then
			#copy the daemon.json
			find $BASEDIR -name "daemon.json" -exec cp -f {} /etc/docker/ \;
			echo "Updating the daemon.json of docker"
			#pkill -SIGSTOP dockerd
			systemctl restart docker
		else
		    echo "============================================The daemon.json was updated.===================================================="
		fi
	else
	    echo "================================the nvidia-docker2 and daemon has been install successfully!====================================="
	fi
}

# function check_docker_runtime {
   # test_docker_daemon=`grep default-runtime /etc/docker/daemon.json | grep -c registry-mirrors`
   # if [ $test_docker_daemon -eq 0 ]; then
      # #copy the daemon.json
      # find $BASEDIR -name "daemon.json" -exec cp -f {} /etc/docker/ \;
      # echo "Updating the daemon.json of docker"
      # #pkill -SIGSTOP dockerd
      # systemctl restart docker
   # else
      # echo "==============================================The daemon.json was updated.======================================================="
   # fi
# }

function install_docker_compose {
   check_docker_compose=`docker-compose version`
   if [ $? -ne 0 ]; then
      echo "=======================================================begin to install docker-compose=============================================="
	  sudo wget -P /usr/local/bin/ https://voxelcloud-storage-public.oss-cn-shanghai.aliyuncs.com/docker-compose
      sudo chmod -R +x /usr/local/bin/docker-compose
      sudo chown root:root /usr/local/bin/docker-compose
	  echo "docker-compose has installed successfully"
   else
      echo "======================================the service docker-compose is running========================================================="
   fi
}

function remove_none_exited_images {
	none_count = `sudo docker images | grep '<none>' | wc -l`
	exited_count = `sudo docker ps -a | grep 'Extied' | wc -l`
	if [ $none_count -ne 0 || $exited_count -ne 0 ]; then
	   echo "=========================================remove the none images====================================================================="
	   sudo docker prune
	else
	   echo "=========================================No invalid images and containers need to be removed!======================================="
	fi
}

function load_tar_or_bz2_images {
	bz2_list=`find $BASEDIR -name "*.bz2"`
	tar_list=`find $BASEDIR -name "*.tar"`
	if [ "$bz2_list" == " " ]; then
		echo "===================================There is currently no images,prepare the image package if necessary！==========================="
	else
		echo "====================================Start to compress or load bz2 package=========================================================="
		for bz2_path in `echo $bz2_list`;
		do
			echo "The current decompressed package is $bz2_path"
			tar -jxvf $bz2_path -C $BASEDIR
			echo "=================================The compressed package $bz2_path has been fully decompressed==================================="
		done
   
		echo "=========================================Start to load tar package==================================================================="
		for tar_path in `echo $tar_list`;
		do
			echo "The current loaded package is $tar_path"
			sudo docker load --input $tar_path
		done
	fi
	if [ $? -eq 0 ];then
		echo "=========================================Remove the bz2 package after decompression tar.bz2 Compressed package========================"
		rm -rf $BASEDIR/*.bz2
		echo "===========================please alert the docker-compose.yml and run docker-compose (-f docker-compose.yml) up -d！！！============="
	fi
	
}
# install nvidia gpu
function check_gpu {
   check_gpu_driver=`dpkg -l|grep nvidia-driver|wc -l`
   if [ "$check_gpu_driver" -eq 0 ] && ! which nvidia-smi &>/dev/null; then
      apt-get install nvidia-driver-390
      echo "After install this GPU driver, please RESTART the computer and exec this scirpt again."
      exit 1
   fi
}
#check the max disk and mount
function choose_max_disk_partition {
   lang=`echo $LANG`
   if [ $lang == "en_US.UTF-8" ]; then
      disks=`sudo fdisk -l|grep dev|grep -e GiB -e TiB|awk -F":| |," '{print $2,$4,$5}'`    # -e on behalf of "or" -e Only one parameter can be passed grep -e GiB -e TiB == egrep "GiB|TiB" == grep -E "TiB|GiB" 
	  echo "$disks"
   elif [ $lang == "zh_CN.UTF-8" ]; then
      disks=`fdisk -l|grep dev|grep -e GiB -e TiB|awk -F"：| |，" '{print $2,$3,$4}'`
	  echo "$disks"
   else
      echo "The Language $lang is not correct!"
      exit 1
   fi
   check=`echo "$disks"|wc -l`
   if [ -z $check ]; then  #if disks is null, then -z -n ! all success
      echo "No disk found!"
      exit 1
   fi
   
   dev=`echo "$disks" |cut -d " " -f 1`
   #num=`echo "$disks" |cut -d " " -f 2`
   scale=`echo "$disks" |cut -d " " -f 3`
	for i in $dev;
	do  
      check_if_mount=`df -h|grep $i|wc -l`
	  for j in $scale;
	  do 
	       if [[ $j == "TiB" && $check_if_mount -eq 0 ]];then
			  maxdisk=$i
			  echo "The maximum mounted disk is $maxdisk"
		   fi
	  done
	done
}

function mount_disk {
   mkfs.ext4 $maxdisk
   mkdir -p /usr/local/vcw
   mount $maxdisk /usr/local/vcw
   configure_fstab $maxdisk
}

function configure_fstab {
   uuid=`blkid|grep $maxdisk|awk '{print $2}'|awk -F'=' '{print $2}'|sed 's/\"//g'`
   check_s_mount=`grep -c $maxdisk /etc/fstab`
   if [ $check_s_mount -eq 0 ]; then
      echo "$maxdisk    /usr/local/vcw           ext4    defaults        0       0"| tee >> /etc/fstab
   fi
}

	if [ $? -eq 0 ];then
		sudo groupadd docker #add docker group
		sudo gpasswd -a $USER docker  #add current user to docker group
		newgrp docker   #update docker group	
	fi
check_openssh
disable_nouveau
install_common_tools
install_docker
install_nvidia_docker2
#check_docker_runtime
install_docker_compose
choose_max_disk_partition
mount_disk
#remove_none_exited_images


echo "======================================================END========================================================================"
exit 0
