#!/bin/bash
echo -----------------------------------------------------------------
echo collect-serverinfo.sh version 1.0.06-08-2019
echo checking if we have sufficient permissisions to run the script
echo -----------------------------------------------------------------
id
if [[ $EUID -ne 0 ]]; then
   echo "*** This script must be run as root, quitting ***" 
   exit 1
fi
echo -----------------------------------------------------------------
echo Detecting OS Distro and version
echo -----------------------------------------------------------------
DISTRO="$(cat /etc/system-release | grep -o '^[^0-9]*')"
VER="$(cat /etc/system-release | grep -o ' [0-9].[0-9]\+')"
echo Distro = $DISTRO
echo Version = $VER
echo -----------------------------------------------------------------
echo Verify this is a supported distro and version
echo -----------------------------------------------------------------
if [[ `echo $DISTRO` == *"CentOS"* ]]; then
   echo "$DISTRO is ok, continuing"
elif [[ `echo $DISTRO` == *"Red Hat"* ]]; then
   echo "$DISTRO is unexpected, continuing anyway"
else
   echo "Unexpected distro $DISTRO doesn't match CentOS, quitting"
   exit 1
fi
if (( $(echo "$VER 6" | awk '{print ($1 >= $2)}') && $(echo "$VER 7" | awk '{print ($1 < $2)}') )); then
centos6=true
echo -----------------------------------------------------------------
echo CentOS 6 Specific tasks
echo -----------------------------------------------------------------
yum install wget -y
wget http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
rpm -ivh epel-release-6-8.noarch.rpm
sed -i "s/mirrorlist=https/mirrorlist=http/" /etc/yum.repos.d/epel.repo
fi

if (( $(echo "$VER 7" | awk '{print ($1 >= $2)}') && $(echo "$VER 8" | awk '{print ($1 < $2)}') )); then
centos7=true
echo -----------------------------------------------------------------
echo CentOS 7 Specific tasks
echo -----------------------------------------------------------------
yum install wget -y
wget http://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
rpm -ivh epel-release-latest-7.noarch.rpm
fi
echo -----------------------------------------------------------------
echo installing facter and net-tools
echo -----------------------------------------------------------------
yum install facter net-tools -y
echo
echo -----------------------------------------------------------------
echo collecting info from facter
echo -----------------------------------------------------------------
facter
echo
if [ $centos7 ] ; then
echo -----------------------------------------------------------------
echo collecting info from systemctl list-units --type service --all --no-page
echo -----------------------------------------------------------------
systemctl list-units --type service --all --no-page
echo
fi
if [ $centos6 ] ; then
echo -----------------------------------------------------------------
echo collecting info from service --status-all
echo -----------------------------------------------------------------
service --status-all
echo
fi
echo -----------------------------------------------------------------
echo collecting routes
echo -----------------------------------------------------------------
route -ve
echo
echo -----------------------------------------------------------------
echo collecting disk block device info
echo -----------------------------------------------------------------
lsblk
echo
echo -----------------------------------------------------------------
echo collecting mount points
echo -----------------------------------------------------------------
mount
echo
echo -----------------------------------------------------------------
echo collecting users who can login to the system
echo -----------------------------------------------------------------
getent passwd | egrep -v '/s?bin/(nologin|shutdown|sync|halt)' | cut -d: -f1
echo
echo -----------------------------------------------------------------
echo collecting iptables information
echo -----------------------------------------------------------------
iptables -L -v
echo
echo -----------------------------------------------------------------
echo collecting name resolution information
echo -----------------------------------------------------------------
echo running command: ping -c 2 tivo.com
ping -c 2 tivo.com
echo running command: cat /etc/resolv.conf
cat /etc/resolv.conf
echo