#!/bin/bash 

function print_step {
    tput setaf 4; echo "[[*]] $1"
}

function echo_s {
    tput setaf 10; echo "[[**]] Success: $1"
}

function echo_f {
    tput setaf 9; echo "[[**]] Failed: $1"
}

function echo_r {
    tput setaf 1; echo "[[**]] Failed: $1"
}

function echo_w {
    tput setaf 11; echo "[[**]] Warning: $1"
}

SSHPASS=$(which sshpass)
if [[ -x "$SSHPASS" ]]
then
        echo_s "sshpass founded"
else
	echo_r "Pleas install sshpass ( apt install sshpass / yum install sshpass )"

        exit 0
fi

# Step 1 - Verify Network Connection
print_step "First we verify network connnection, we need one argument IP or Domain: format 1.2.3.4 or our.server.google.com"
read HOST

#verify network access ( telnet port 22 )

function network_access {
NC=$(which nc)
if [[ -x $NC ]]
then
network=$(nc -z -v -w10 $HOST 22 )
if [[ $? == 0 ]] ; then
	echo_s "Network connectivity work."
else
	echo_f "Network connectivity problem. Finish."
	exit 127
fi
else
	echo_r "Please install nc."
	exit 127
fi
}


# Step 2 - SSH logon
print_step "We need two additional parameters: login and password"
print_step "Write login:"
read LOGIN
print_step "Write password ( if you want to use a ssh-key, press enter ):"
read PASSWORD

function ssh_logon_password (){
status=$(sleep 2 && sshpass -p $PASSWORD ssh -o StrictHostKeyChecking=no -o BatchMode=no -o ConnectTimeout=5 $LOGIN@$HOST echo ok 2>&1)

if [[ $status == ok ]] ; then
  echo_s "Logon success. Connection to host possible."
elif [[ $status == "Permission denied"* ]] ; then
  echo_f "Logon failed. Smth goes wrong. Bad Credentials. Finish."
  exit 127
else
  echo_f "Unknown error"
  exit 127
fi
}


# Step 2b Verify user / root / sudo 

function verify_user_sudo {
CHKSUDO=$(sleep 2 && sshpass -p $PASSWORD ssh -o StrictHostKeyChecking=no -o BatchMode=no -o ConnectTimeout=5 $LOGIN@$HOST sudo -i id | grep "uid=0(root) gid=0(root) groups=0(root)" | wc -l)
if [[ $LOGIN == root ]] ; then
	echo_s "Root permission granted. " 
elif [[ $CHKSUDO -ge 0 ]] ; then
	echo_s "Account: $LOGIN can switch to root using sudo"
else
	echo_f "ERROR: problem with access to root"
fi
}

# Step 3 - Verify CPU / MEM

function cpu_mem {
CPU=$(sleep 2 && sshpass -p $PASSWORD ssh -o StrictHostKeyChecking=no -o BatchMode=no -o ConnectTimeout=5 $LOGIN@$HOST cat /proc/cpuinfo  | grep processor  | wc -l)
MEM=$(sleep 2 && sshpass -p $PASSWORD ssh -o StrictHostKeyChecking=no -o BatchMode=no -o ConnectTimeout=5 $LOGIN@$HOST free -g | grep Mem | column -t | cut -f 3 -d ' ')
if [[ $CPU -ge 2 ]] ; then
	echo_s "Number of CPU: $CPU, recommended: 2"
else
	echo_f "Number of CPU $CPU, recommended 2"
fi
if [[ $MEM -gt 4 ]]; then
	echo_s "Memory: $MEM GB, recommended 4GB!"
else
	echo_f "Memory: $MEM GB but recommended 4GB!"
fi
}

# Step 4 - Verify Support OS
function os_verification {
DISTRIBUTION=$(sleep 2 && sshpass -p $PASSWORD ssh -o StrictHostKeyChecking=no -o BatchMode=no -o ConnectTimeout=5 $LOGIN@$HOST cat /etc/redhat-release | grep -i "CentOS\|RedHat" | wc -l)
VERSION6=$(sleep 2 && sshpass -p $PASSWORD ssh -o StrictHostKeyChecking=no -o BatchMode=no -o ConnectTimeout=5 $LOGIN@$HOST cat /etc/redhat-release | grep "release 6.*" | wc -l)
VERSION7=$(sleep 2 && sshpass -p $PASSWORD ssh -o StrictHostKeyChecking=no -o BatchMode=no -o ConnectTimeout=5 $LOGIN@$HOST cat /etc/redhat-release | grep "release 7.*"| wc -l)
if [[ $DISTRIBUTION == 1 ]] ; then
	echo_s "Distribution is correct CentOS/RedHat"
	if [[ $VERSION6 == 1 ]] ; then
		echo_s " * OS version is 6.*. You can install MW-Portal"
		VERSIONOS=6
                CHECKTCP=./check_tcp6
	elif [[ $VERSION7 == 1 ]] ; then
		echo_s " * OS version is 7.*. You can install WFM"
		VERSIONOS=7
                CHECKTCP=./check_tcp6
	else
		echo_f "Unsupported OS version, required version Centos/RHEL 6.* for MW-Portal or 7.* for WFM"
	fi
else
	echo_f "Bad OS, installation not possible run. Required Centos/RHEL 6/7"
fi
}

# Step 5 - Disk

print_step "Verify space, partition - manually"
DISK=$(sleep 2 && sshpass -p $PASSWORD ssh -o StrictHostKeyChecking=no -o BatchMode=no -o ConnectTimeout=5 $LOGIN@$HOST df -h)
echo $DISK
echo "#############################################################"

# Step 6 
function salt_access {
$(sleep 2 && sshpass -p $PASSWORD scp $CHECKTCP $LOGIN@$HOST:~/check_tcp)
SALTACCESS=$(sleep 2 && sshpass -p $PASSWORD ssh -o StrictHostKeyChecking=no -o BatchMode=no -o ConnectTimeout=5 $LOGIN@$HOST ./check_tcp saltmaster.cubiware.com -p 4506 -t 20 | grep OK | wc -l )

if [[ $SALTACCESS == 1 ]] ; then
	echo_s "Can connect to SALTMASTER"
else
	echo_w "Can't connect to SALTMASTER | OPTIONAL!!"
fi
}

# Step 7 - Verify access to internet 
function intenet_access {
SALTACCESS=$(sleep 2 && sshpass -p $PASSWORD ssh -o StrictHostKeyChecking=no -o BatchMode=no -o ConnectTimeout=5 $LOGIN@$HOST ./check_tcp wp.pl -p 80 -t 20 | grep OK | wc -l )

if [[ $SALTACCESS == 1 ]] ; then
        echo_s "Can connect to website"
else
        echo_w "I can't connect to website.| OPTIONAL!!"
fi
}

# Step 8
function create_user {
$(sleep 2 && sshpass -p $PASSWORD ssh -o StrictHostKeyChecking=no -o BatchMode=no -o ConnectTimeout=5 $LOGIN@$HOST sudo useradd test)
VERIFY=$(sleep 2 && sshpass -p $PASSWORD ssh -o StrictHostKeyChecking=no -o BatchMode=no -o ConnectTimeout=5 $LOGIN@$HOST id test | grep uid | grep test | wc -l )
RMUSER=$(sleep 2 && sshpass -p $PASSWORD ssh -o StrictHostKeyChecking=no -o BatchMode=no -o ConnectTimeout=5 $LOGIN@$HOST sudo userdel -r test)
if [[ $VERIFY == 1 ]] ; then
	echo_s "User created, verified, removed"	
	$RMUSER
else
	echo_f "Can't create user"
fi
}

# Step 9 DNS
function verify_dns {
DNSACCESS=$(sleep 2 && sshpass -p $PASSWORD ssh -o StrictHostKeyChecking=no -o BatchMode=no -o ConnectTimeout=5 $LOGIN@$HOST ping -W 1 -c1  saltmaster.cubiware.com | grep "77.79.228.210" | wc -l )
DNSCONFIG=$(sleep 2 && sshpass -p $PASSWORD ssh -o StrictHostKeyChecking=no -o BatchMode=no -o ConnectTimeout=5 $LOGIN@$HOST cat /etc/resolv.conf | grep nameserver | wc -l)

if [[ $DNSACCESS == 1 ]] ; then
	echo_s "Access to DNS working!"
elif [[ $DNSCONFIG == 1 ]] ; then
        echo_w "DNS configured in system. But access impossible."
else
        echo_f "Can't find dns configuration. DNS problem"
fi
}

# Step 10  NFS
function nfs_mounts {
print_step "Check NFS mounted"
NFSMOUNT=$(sleep 2 && sshpass -p $PASSWORD ssh -o StrictHostKeyChecking=no -o BatchMode=no -o ConnectTimeout=5 $LOGIN@$HOST cat /etc/fstab | grep "catcher\|poster" | wc -l)
if [[ $NFSMOUNT -gt 0 ]] ; then
	echo_s "NFS mounted. Catcher and poster exist"
else
	echo_w "Need NFS for catcher and poster if you want install WFM! It\'s required but maybe you\'ll setup it later."
fi
}
#################################################################################

network_access
ssh_logon_password
verify_user_sudo
cpu_mem
os_verification
salt_access
intenet_access
create_user
verify_dns
nfs_mounts
