#!/bin/sh
# fallocate -l 4G /swapfile
dd if=/dev/zero of=/swapfile count=4000 bs=1MiB
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo "/swapfile   none    swap    sw    0   0" >> /etc/fstab
