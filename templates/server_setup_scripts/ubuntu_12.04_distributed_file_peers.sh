#!/bin/bash -vx

# now setup volumes for use with gluster
echo '%{HOSTS}' > /vagrant/distributed_file_hosts.txt
perl /vagrant/setup_%{DISTRIBUTED_FILE_SYSTEM}_peers.pl --host /vagrant/distributed_file_hosts.txt

