#!/bin/bash

add-apt-repository -y ppa:semiosis/ubuntu-glusterfs-3.5
apt-get update
apt-get -q -y --force-yes install glusterfs-server
