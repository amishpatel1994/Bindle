#!/bin/bash -vx

# now setup volumes for use with whatever distributed file system is to be used
echo '%{HOSTS}' | grep master > /vagrant/distributed_file_hosts.txt
perl /vagrant/setup_%{DISTRIBUTED_FILE_SYSTEM}_peers.pl --host /vagrant/distributed_file_hosts.txt

