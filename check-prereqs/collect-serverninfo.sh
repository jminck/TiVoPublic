#!/bin/bash

echo -----------------------------------------------------------------
echo installing facter
echo -----------------------------------------------------------------
yum install facter -y
echo
echo -----------------------------------------------------------------
echo collecting info from facter
echo -----------------------------------------------------------------
facter -j
echo
echo -----------------------------------------------------------------
echo collecting info from systemctl
echo -----------------------------------------------------------------
systemctl list-units --type service --all --no-page
echo
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
