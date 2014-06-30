#!/bin/bash -vx

# now setup volumes for use with whatever distributed file system is to be used
echo '%{HOSTS}' > /vagrant/distributed_file_hosts.txt
perl /vagrant/setup_%{DISTRIBUTED_FILE_SYSTEM}_service.pl --host /vagrant/distributed_file_hosts.txt --dir-map /vagrant/distributed_file_volumes_report.txt

