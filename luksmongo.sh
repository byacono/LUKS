#!/bin/bash
 
# !!! This script assumes that the device needing to be formatted and encrypted is /dev/sdb
# !!! Also... be sure to copy and store the generated encryption key file from /root
 
# Note that the secondary drive will be mounted at /var/lib/mongodb,
# ... which is the default location for MongoDB data files on Ubuntu and Mongo at least v2.6 
 
 
# add PPA for mongodb
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10
echo 'deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen' | sudo tee /etc/apt/sources.list.d/mongodb.list
sudo apt-get update
 
 
# create a keyfile that will be used for the device encryption
# key should be read-only by root only
sudo dd if=/dev/urandom of=/root/mongo-efs-key bs=1024 count=4
sudo chown root:root /root/mongo-efs-key
sudo chmod 400 /root/mongo-efs-key
 
# create partition on /dev/sdb
sudo parted /dev/sdb mklabel msdos
sudo parted /dev/sdb mkpart primary 0% 100%
 
# install cryptsetup and create encrypted container in new device
sudo apt-get install -y cryptsetup
sudo umount /dev/sdb1
sudo cryptsetup luksFormat -d /root/mongo-efs-key --batch-mode /dev/sdb1
sudo cryptsetup luksOpen -d /root/mongo-efs-key /dev/sdb1 mongoefs
 
# format and mount our encrypted volume
sudo mkfs.ext4 /dev/mapper/mongoefs
sudo mkdir -p /var/lib/mongodb
sudo mount /dev/mapper/mongoefs /var/lib/mongodb
 
# update the crypttab and fstab files with new partitions
echo "mongoefs /dev/sdb1 /root/mongo-efs-key luks" | sudo tee --append /etc/crypttab > /dev/null
sudo update-initramfs -u -k all
echo "/dev/mapper/mongoefs /var/lib/mongodb ext4 defaults 0 2" | sudo tee --append /etc/fstab > /dev/null
 
# install mongo
sudo apt-get install -y mongodb-org
 
# set permissions for mongo on our encrypted and mapped device
sudo chown mongodb:mongodb /var/lib/mongodb
