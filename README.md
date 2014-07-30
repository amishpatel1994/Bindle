## Table of Contents

* [About Bindle](#about-bindle)
* [Build and Source Control](#build-source-control)
* [Installing Bindle](#installing)
    * [Note about Versions](#note-about-versions)
    * [Getting "Boxes"](#getting-boxes)
    * [Configuration Profiles](#configuration-profiles)
      * [Filling in the config file](#filling-in-the-config-file)
      * [Configuration for VirtualBox](#configuration-for-virtualbox)
    * [RAM and CPU Core Requirements](#ram-and-cpu-core-requirements)
* [Running the Cluster Launcher](#running-the-cluster-launcher)
* [Destroying the Clusters](#destroying-the-clusters)
* [SeqWare Examples](#seqware-bag)
* [Persistance of Ephemeral Disks - AWS](#persistance-of-ephemeral-disks---aws)
* [Launching a single node instance from an AMI Image](#launching-a-single-node-instance-from-an-ami-image)
* [Logging](#logging)
* [Controlling the VM](#controlling-the-vm)
* [CentOS Information](#centos-information)
* [Debugging](#debugging)
* [TODO](#todo)


## About Bindle

This project is a wrapper around [Vagrant](http://www.vagrantup.com/) and
provides the ability to launch either a single node or a cluster of compute
nodes configured with an [Ansible](http://www.ansible.com/) playbook.
This lets you build Linux virtual machines from scratch, ensuring
you development/testing/production VMs are clean and your configuration process
is fully reproducible.  The big difference between building a cluster with this
script vs. Vagrant directly is Vagrant provides a single pass at running
provisioning script which actually makes it quite difficult to pass runtime
information like the domain names/IP addresses of cluster nodes and to setup
software where order matters like HDFS before HBase.  This tool, however,
launches one or more instances then queries Vagrant to identify the external 
and internal IP address of each of the launched instances. 

This script then builds an Ansible inventory and invokes the playbook 
while passing along some variables and logging the results.  

What we have found this useful for is building clusters (both Hadoop and
GridEngine-based) on a variety of cloud environments without having to retool
our process for each cloud.  We can focus on the specifics of each project,
what software needs to be installed, the configuration, and environment changes
all without having to code anything that is cloud-specific.  Because the
process is so generic we can use it to support a wide variety of in-house
software projects and use cases.  For example, some projects use
Bindle to create automated test environments, others use it to create
workflow development environments, data processing environments, or even
production system installs.

In separate repositories, we provide secondary provisioning
Ansible scripts that setup a single-node or multi-node SeqWare cluster configured
to use the Oozie workflow engine. Since this Vagrant wrapper is fairly generic
the same process can be adapted to build other cluster types to serve other
projects.  

You can also base anything that needs a Hadoop and/or GridEngine cluster of
machines created on a variety of cloud platformsn on our Ansible playbooks.

We include sample JSON
configs in our sister repositories that show you how to build
nodes/clusters for the following projects:

* [SeqWare Pipeline](https://github.com/SeqWare/seqware-bag) 
** (with Oozie-Hadoop and/or Oozie-SGE backends) and associated SeqWare projects (WebService, MetaDB, etc)
* the [TCGA/ICGC PancCancer Project](https://github.com/ICGC-TCGA-PanCancer/pancancer-bag)

## Build & Source Control

Please use [HubFlow](http://datasift.github.io/gitflow/) for development. The
working branch is "develop".  If you need to make changes work on a feature
branch and make a pull request to another developer when ready to merge with
develop.  See the HubFlow docs above for a detailed description of this
process.

## Installing

Install VirtualBox from [Oracle](https://www.virtualbox.org/) which will let
you launch a local node or cluster of virtual machine nodes on your desktop or
local server. If you will *only* launch a node or cluster of nodes on Amazon
or an OpenStack cloud you can skip this step.

Install dependencies:

    sudo apt-get install gcc make

Install bindle dependencies:

    sudo apt-get update
    sudo apt-get install software-properties-common
    sudo apt-add-repository ppa:ansible/ansible
    sudo apt-get update
    sudo apt-get install ansible libjson-perl libtemplate-perl libconfig-simple-perl libcarp-always-perl libipc-system-simple-perl make gcc

Install Vagrant using the package from their
[site](http://downloads.vagrantup.com/) that is correct for your platform.  For
example, I used the following Ubuntu 12.04 64-bit:

    wget https://dl.bintray.com/mitchellh/vagrant/vagrant_1.6.3_x86_64.deb 
    sudo dpkg -i vagrant_1.6.3_x86_64.deb

You then need to install plugins to handle AWS, vCloud, and/or OpenStack. The
Virtualbox provider is available out of the box with Vagrant. You do this step
as the user that will run Vagrant and the SeqWare Vagrant wrapper.

    vagrant plugin install vagrant-aws
    vagrant plugin install vagrant-openstack-plugin 
    vagrant plugin install vagrant-vcloud

The current version of the vagrant-vcloud plugin needs to be running with 
Vagrant 1.5. If using version 1.4 one variable name will need to be modified.
I forget exactly where the variable is but there will be an error thrown and
based on the error you will need to remove the string 'URL' from the end of the
variable.
The bin/launcher/launch_cluster.pl Perl script requires Perl (of course) and also a
few modules.  They should already be installed if you went through install bindle dependencies 
but if not, you can install these using [CPAN](http://www.cpan.org/) or via
your distribution's package management system. Google "cpan perl install" for
more information if you're unfamiliar with installing Perl packages. I highly
recommend using PerlBrew to simplify working with Perl dependencies if you
do not use your native package manager as shown below for Ubuntu:

* Getopt::Long: should be installed by default with Perl
* Data::Dumper: should be installed by default with Perl
* JSON: eg "sudo apt-get install libjson-perl" on Ubuntu 12.04
* Template: eg "sudo apt-get install libtemplate-perl" on Ubuntu 12.04
* Config::Simple: eg "sudo apt-get install libconfig-simple-perl" on Ubuntu 12.04
* Carp::Always: eg "sudo apt-get install libcarp-always-perl"
* IPC::System::Simple: eg "sudo apt-get install libipc-system-simple-perl"

To check to see if you have these you do:

    perl -c bin/launcher/launch_cluster.pl

It should exit without an error message. 
For detailed explanation on setting up a launcher and launching clusters from that, please refer to
the [Pancancer Cluster Launch ReadMe](https://github.com/SeqWare/vagrant/blob/develop/PANCAN_CLUSTER_LAUNCH_README.md)

### Note About Versions

There have been some reports of problems with the latest version of Vagrant
and Vagrant plugins for OpenStack and/or AWS.  Here is what we currently use on
Ubuntu 12.0.4 LTS which we use to launch nodes/clusters on OpenStack or AWS:

* Vagrant: 1.6.3
* Vagrant plugins:
    * vagrant-aws (0.5.0)
    * vagrant-openstack-plugin (0.7.0)
* Ansible 1.6.8

On the Mac we use the following to launch VMs on VirtualBox, vCloud (VMWare), or AWS:

* Vagrant: 1.6.3
* Vagrant plugins:
    * vagrant-aws (0.5.0)
    * vagrant-vcloud (0.1.1)
* VirtualBox: 4.2.18 r88780

These work correctly, if you use a different version and run into problems
please try one of these versions.

## Getting "Boxes"

This is still needed but it should happen automatically the first time you
use Bindle on VirtualBox.

If you are running using VirtualBox you can pre-download boxes which are
images of computers ready to use.  The easiest way to do this is to find the
URL of the base box you want to use here:

http://www.vagrantbox.es/

For example, to download the base Ubuntu 12.04 box you do the following:

    vagrant box add Ubuntu_12.04 http://cloud-images.ubuntu.com/precise/current/precise-server-cloudimg-vagrant-amd64-disk1.box

Keep in mind this is primarily aimed at developers making a new profile config.
For the existing ones we provide they already link to the box that will be
pulled in on first launch.  This may take a while on a slow connection.

For Amazon or an OpenStack cloud a "dummy" box will be used and is already
configured in the code.

## Configuration Profiles

Since this Vagrant wrapper can be used for many different projects based on the
Bash shell scripts used to configure the hosts, we included several example
configuration templates in:

* [seqware-bag](https://github.com/SeqWare/seqware-bag/tree/develop/sample_configs)
* [pancancer-bag](https://github.com/ICGC-TCGA-PanCancer/pancancer-bag/tree/master/sample_configs)

Please remember to copy the file path of desired template(for example
templates/sample_configs/vagrant_cluster_launch.seqware.single.json.template)
and place it in the appropriate config file described below.

Fill in your various platform settings depending on what cloud provider you use
(Vcloud(vcloud.cfg), Amazon(aws.cfg), or OpenStack(os.cfg)). In order to get help
on filling the config files, please refer to config/sample.cfg:
    
    vim config/os.cfg
    
### Filling in the config file

One thing you must keep in mind before filling in the config files is not to delete any of the default
parameters you are not going to be needing. Simply, leave them blank if that is the case. 
Also, please refer to "Configuration for Virtualbox" if you want to provision clusters on Virtualbox

#### Platform Specific Information

This section of the config file contains all the information that is required to set up the platform.
You need to fill in the parameters for the specific platform you want to launch clusters in by modifying either 
os.cfg for OpenStack, aws.cfg for AWs, or vcloud.cfg for VCloud

Let us go through the parameters that might confuse you when you are filling the config file. I will not be going 
through the most obvious parameters (ie. user, apikey, etc):

    [platform]
    # can be either openstack(os) or aws or vcloud
    type=os/aws/vcloud
    
    # asks for the name of your pem file. Please make sure you have the pem file under ~/.ssh on your launcher host
    ssh_key_name=ap-oicr-2
    
    # asks for the type of node you want to launch (m1.small, m1.medium, m1.xlarge, etc)
    instance_type=m1.xlarge
    
    # This list is to indicate the devices you want to use to setup gluster file system on.
    # To find out the list of devices you can use, execute “df | grep /dev/” on an instance currently running on the same platform. 
    # DO NOT use any device that ends with "a" or "a" and a number following it(sda or sda1) because these are used for root partition
    # Also, if you don't want to use any devices to set up gluster, please keep the value empty (gluster_device_whitelist=''). You need to do that when you are dealing with a single node cluster or when you have no devices to work with
    # For AWS, when you create an EBS volume by using --aws-ebs parameter, it creates an "sdf" device, so specify "f" in your list gluster_devices
    # Now, if you want to use "sdb/xvdb" and "sdf/xvdf" then your list should look like the following:
    gluster_device_whitelist='--whitelist b,f'

    # this parameter indicates the path you want to use to set up gluster IF you don't have any devices to work with
    # If you don't want to use directories, simply leave this parameter empty (gluster_directory_path=''). This should be the case for single node clusters
    # If you don't have devices, include the path and folder name that can be used instead to set up the volumes for a multi-node cluster: 
    gluster_directory_path='--directorypath /mnt/volumes/gluster'
    
The other platform specific parameters are self explanatory. In the config file, there is a "fillmein" value which indicates that you
defintely have to fill those in to have bindle working properly. The others are deafult values that you may use unless otherwise stated.

#### Cluster Specific Information

This information exists in small blocks name cluster1, cluster2, etc. These blocks contain essential information such as number of nodes,
target_directory, the json_template file path, and floating ips which is specific to OpenStack only since the other 
environments have the ability to generate the floating ips on their own.
    
Please note that you can create a new cluster by copy-pasting the existing cluster1
block and modifying the configs for it or you can simply modify cluster1 configs and use that.
Feel free to change the number of nodes (min 1, max recommended 11). Please note that 
if the number of nodes is 1, it means that there will be 1 master and 0 worker nodes. 
Also, you need the same number of floating ips as the number of nodes if you are working with openstack.
In addition, the list is separated by a comma and there is no need to put this list in quotations.
An example cluster block will look something like this:

    # Clusters are named cluster1, 2, 3 etc.
    # When launching a cluster using launch_cluster.pl
    # use the section name(cluster1 in this case) as a parameter to --launch-cluster
    [cluster1]
   
    # this includes one master and four workers
    number_of_nodes=4
   
    # specific to Openstack only; must have 4 floating ips since we need 4 nodes
    floating_ips= 10.0.20.123,10.0.20.157,10.0.20.135,10.0.20.136
   
    # this specifies the output directory where everything will get installed on the launcher
    target_directory = target-os-2
   
    #this contains the path to the json template file this cluster needs
    json_template_file_path = templates/sample_configs/vagrant_cluster_launch.pancancer.seqware.install.sge_cluster.json.template
 
To use a specific cluster block, you need to use the section name of that block as a parameter to --launch-cluster when you
are running the launch_cluster perl script.

### Configuration for VirtualBox

Please note for VirtualBox, you will need to use the old configuration technique:
    
    # copy the json template over
    cp templates/sample_configs/vagrant\_cluster_launch.seqware.single.json.template vagrant_cluster_launch.json
    # make any required changes to the json template
    vim vagrant_cluster_launch.json
    
You can fill in the required information and move on to the next step.

If you use the template recommended above you will have a 1 node Hadoop cluster
(with Mapred, HDFS, HBase, Oozie, Hue, etc installed) along with the SeqWare
software stack installed.  This environment should be ready for use with out
Getting Started Guides for this project. You can also choose another template,
such as "templates/sample_configs/vagrant_cluster_launch.seqware.cluster.json.template",
that will give you a 4 node cluster.

## RAM and CPU Core Requirements

The short answer is make sure your machine (local VM, Amazon instance type,
etc) has at least 2 cores and 12G of RAM. You can certainly use less but our
SeqWare tutorials on http://seqware.io will not work properly. If you're using
Bindle to build environments for a non-SeqWare project then the memory
requirements are set by you.

The SeqWare "HelloWorld" example workflow will schedule using 8G of RAM.  So
please make sure you launch on a machine instance type (AWS, Google Cloud, etc)
with at least 12G of RAM.  For VirtualBox, you should do the same.  Our default
profile for VirtualBox requests 12G of RAM and 2 cores.  If you need to change
this setting please see the --vb-ram and --vb-cores options that let you
override the memory/core requirements in VirtualBox ONLY.  Keep in mind for AWS
and other clouds the RAM and Cores are determinted by the instance type you
choose not by the --vb-ram and --vb-cores options.

## Running the Cluster Launcher

The wrapper script that controls the system described above is called
"bin/launcher/launch_cluster.pl". 

Please note that a detailed explanation of the cluster launching process
for virtual box is located [here](https://github.com/SeqWare/pancancer-info/blob/develop/docs/workflow_dev_node_with_bindle.md)
A detailed explanation of the cluster launching process for other environments 
is located [here](https://github.com/SeqWare/pancancer-info/blob/develop/docs/prod_cluster_with_bindle.md)

Examples of launching in different environments include:

    # for AWS
    perl bin/launcher/launch_cluster.pl --use-aws --use-default-config --launch-cluster <cluster-name> 
    # for OpenStack
    perl bin/launcher/launch_cluster.pl --use-openstack --use-default-config --launch-cluster <cluster-name>

"clustername" represents the cluster block you want to run from the config file (Ex: cluster1).

Please note that you can still use the old way to set up configurations in the json template file itself for any environment. 
That is, copying the template file over like this (you must use this way if you are launching a cluster using virtualbox):

    # for Virtualbox
    cp templates/sample_configs/vagrant_cluster_launch.pancancer.seqware.install.sge_node.json.template vagrant_cluster_launch.json
    # modify the .json template to include your settings, for AWS you need to make sure you fill in the "AWS_*" settings
    vim vagrant_cluster_launch.json
    # now to launch the node
    perl vagrant_cluster_launch.pl --use-aws --working-dir target-aws-1 --config-file vagrant_cluster_launch.json
    
## Destroying the Clusters

The script that takes care of the process required to terminate a cluster is located at 
"bin/launcher/destroy_cluster.pl". To destroy a cluster, simply run the following command:

     # assumes you are in the Bindle directory
     perl bin/launcher/destroy_cluster.pl --cluster-name <target-dir>
     
The target-dir is the directory path of your cluster folder(Ex. target-aws-1/). This will remove
the cluster from the appropriate environment but it is advised to check the web interface to make sure
that the nodes are deleted.

## seqware-bag

Using these
examples, you will need to modify the configuration template and copy them to
vagrant_cluster_launch.json (or another file, using the --config-file option).

The following templates exist for SeqWare-bag, they will be described in more
detail in that repo's [README](https://github.com/SeqWare/seqware-bag):


In brief, in order to use these projects together

	mkdir working_dir
	cd working_dir
	git clone git@github.com:CloudBindle/Bindle.git
	cd Bindle && git checkout 2.0-alpha.0
	cd ..
	git clone https://github.com/SeqWare/seqware-bag
	cd seqware-bag && git checkout 1.0-alpha.0 
	cd ../Bindle
	cp ../seqware-bag/sample_configs/vagrant_cluster_launch.seqware.install.sge_cluster.json.template vagrant_cluster_launch.seqware.install.sge_cluster.json 
        vim vagrant_cluster_launch.seqware.install.sge_cluster.json
        perl bin/launcher/launch_cluster.pl --use-openstack --working-dir target --config-file vagrant_cluster_launch.seqware.install.sge_node.json
        
In order to re-run Ansible when doing development:

        perl bin/launcher/launch_cluster.pl --use-openstack --working-dir target --config-file vagrant_cluster_launch.seqware.install.sge_node.json --run-ansible

In order to run with pan-cancer modifications as well, please checkout and use the contents of [pancancer-bag](https://github.com/ICGC-TCGA-PanCancer/pancancer-bag) as well. 


## Persistance of Ephemeral Disks - AWS

Amazon instances provisioned using Bindle store information such as file inputs and outputs, the /home directory, and the Oozie working directory in /mnt which is normally backed by ephemeral drives. If you wish them to persist (when rebooting instances or distributing images) you will need to mount them on an EBS volume instead. Follow the steps below to get an AMI image up and running with a single node instance!

### Step 1 - Creating and Formatting an EBS volume

1. Log onto the Amazon Web Console and navigate to EC2 -> Elastic Block Store -> Volumes. 
2. Click on "Create Volume"
   * The size for the EBS volume should be large enough to fit everything from the ephemeral drive. It is recommended to use 1000 GB. 
   * Choose "Magnetic" as the Volume type
   * IMPORTANT: Make sure the availability zone of the volume is the same as that of the single node instance!
3. Click Create!
4. Now, Right click on the volume we just created and attach it to the single node instance you want to create an image out of and choose /dev/sdf as the device

Log onto the single node instance via SSH and follow these steps to format the EBS volume:

    # login as root user
    sudo su -
    # format the device /dev/xvdf
    mkfs.ext4 /dev/xvdf

    
### Step 2 - Mounting the EBS Volume at Ephemeral Storage's mountpoint

This step assumes you have logged into the single node instance and logged in as the root user

    # Create a back up of the contents in /mnt
    mkdir /temp_mnt
    # Copy the contents of /mnt to your temporary location. Preserve timestamps and permissions 
    cp -R -p /mnt/* /temp_mnt
    # Unmount the /mnt
    umount -l /mnt
    # Mount /mnt on the EBS volume
    mount /dev/xvdf /mnt
    # Copy the contents of /temp_mnt to /mnt. Preserve timestamps and permissions
    cp -R -p /mnt/* /temp_mnt
    # update /etc/fstab. Add the following line to it: 
    # /dev/xvdf       /mnt    auto    defaults,nobootwait,comment=cloudconfig 0       2
    # Also get rid of the /dev/xvdb line
    vim /etc/fstab

After this step, please reboot the instance from the AWS console and then run the helloworld workflow to make sure
that the mounting process did not break anything.

### Step 3 - Creating a Snapshot of the EBS Volume

1. Log onto the Amazon Web Console and navigate to EC2 -> Elastic Block Store -> Volumes. 
2. Right click the EBS volume you are working with and select "Create Snapshot"
3. Give it an appropriate name(Ex. Seqware_1.0.13_Bindle_1.2) and hit create

### Step 4 - Creating the AMI image if the single node instance

1. Log onto the Amazon Web Console and navigate to EC2 -> Instances -> Instances
2. Right click on the single node instance and select "Create Image"
3. Give it an appropriate Image name(Ex. Seqware_1.0.13_Bindle_1.2) and choose the snapshot we just created for the EBS volume. 
4. Click Create Image! 

You should now have a functioning AMI. The next step would be to launching an instance from the AMI image and running the HelloWorld Workflow to make sure it works. The guide to creating an instance from an AMI image is located below.

## Launching a single node instance from an AMI image

1. Log onto the Amazon Web Console and navigate to EC2 -> Images -> AMI
2. Choose the appropriate AMI and select Launch
3. Choose the Instance Type and then, navigate to step 4. In this step, remove the Instance Store 0 volume from the list if it exists.
4. Click Review and Launch and you are done!

You now have a workflow development environment and a place where you can run workflows!

<!---
## OICR Examples

SeqWare isn't the only project using this Vagrant wrapper.  We're using the
same infrastructure for running the ICGC DCC data portal on OpenStack and
Amazon. In the future we will add additional ICGC DCC software project
profiles. These are not ready for outside users at this time but we expect
other users in the future to launch DCC Portals and Validation systems using
something similar to the below.

### General OICR Settings

The templates below do not include our OpenStack settings but you can see Brian for OICR-specific
settings which are also described in more detail here:
https://wiki.oicr.on.ca/display/SEQWARE/Cluster+or+Node+Launching+with+Vagrant

### ICGC DCC Portal - Small Cluster

This will spin up a standard, 2 node SeqWare cluster (using Oozie-Hadoop), will
setup elasticsearch, will download a dump of the (small) elasticsearch DCC
index, load the dump into elasticsearch, and launch the DCC Portal web app on
port 8998.

Keep in mind you should edit the json below before you launch to make sure your
floating IP addresses and other settings are correct.  Also, the specific index
dump file and DCC Portal jar file are hard coded in the provision scripts
referenced inside the JSON so you will want to change these if there's an
update.  Also, take a look at templates/DCC/settings.yml which has the index
name embedded and will need to change if the index is updated.

    # use this template: templates/sample_configs/vagrant_cluster_launch.dcc_small_portal.cluster.json.template
    # Don't forget to place the path of the template file in your connfig file!
    vim config/os.cfg
    # launch, use the correct command line args for you 
    perl bin/launcher/launch_cluster.pl --use-openstack --use-default-config --launch-cluster cluster-name

Once this finishes launching you can browse the DCC Portal at http://master_node_IP:8998/.

### ICGC DCC Portal - Large Cluster

This is the same as the previous example but defaults to an 8 node cluster (one
master, 7 workers). It also calls scripts that reference the large
Elasticsearch DCC Portal index dumps. In the future we will increase this
number, optimize the configuration to better take advantage of the node number,
and explore HA options.

    # use this template: templates/sample_configs/vagrant_cluster_launch.dcc_large_portal.cluster.json.template 
    # Don't forget to place the path of the template file in your connfig file!
    vim config/os.cfg
    # launch, use the correct command line args for you 
    perl bin/launcher/launch_cluster.pl --use-openstack --use-default-config --launch-cluster cluster-name

--->

## Logging

Every node launched by launch_cluster.pl has it's own log file that you
can view (or watch during cluster building).  Take a look inside the directory
specified in the --working-dir option.  There you should see a .log file for
each server being launched (for a cluster) or just master.log if you launched a
node.  You can use "tail -f <logname>" to watch the progress of building your
VMs.

### Re-running Ansible

Note that Ansible playbooks should be designed to run idempotently (and Ansible provides many tools to aid in this). Therefore, it should be possible to re-run the Ansible steps for development purposes or to test an environment for any major issues. You can re-run ansible-enabled deployments via the following command to the launcher script which provides a working-dir and a config-file. 

    perl bin/launcher/launch_cluster.pl --working-dir target-os-cluster --config-file vagrant_cluster_launch.json  --run-ansible

## AWS - Regions and Availability Zones

In order to specify regions and zones, JSON templates support two variables AWS\_REGION and AWS\_ZONE. By default, we provision in us-east-1 and randomly across zones. You can specify one or the other. For example, to provision in us-east-1 in zone a: 

    "AWS_REGION": "us-east-1",
    "AWS_ZONE": "a",

## AWS - Additional EBS Space

In order to add extra EBS volumes across the board, use the following syntax in order to provision a 400 and 500 GB volume attached to each node:

     perl bin/launcher/launch_cluster.pl --use-aws --aws-ebs 400 500


## Controlling the VM

Once the launch_cluster.pl script finishes running you will have one or
more VM instances running on a given cloud or local VM environment.
Unfortunately, Bindle does not provide the full range of VM lifecycle
management e.g. suspend, shutdown, ssh connection automation, etc.  Vagrant
does provide these functions and you can find more information at
[Vagrant](http://vagrantup.com).

Here's a quick overview:

    # first, cd to your --working-dir, in this case target-sge
    cd target-sge
    # you will see directories for each VM, such as master
    cd master
    # once in these directories you can issue Vagrant commands
    # check the status of the VM
    vagrant status
    # suspend
    vagrant suspend
    # resume
    vagrant resume
    # shutdown the VM
    vagrant halt
    # restart the VM
    vagrant up
    # ssh to the machine
    vagrant ssh
    # terminate and remove the VM
    vagrant destroy

*Do not forget to shut down your instances!*


## Veewee Installation and Usage Instructions (Mac)

VeeWee can be used to create CentOS base boxes 

1. Get veewee from here, as follows:
    `git clone https://github.com/jedi4ever/veewee.git`

2. Install RVM as follows:
    ```Shell
    mkdir -p ~/.rvm/src && cd ~/.rvm/src && rm -rf ./rvm && \
    git clone --depth 1 git://github.com/wayneeseguin/rvm.git && \
    cd rvm && ./install
    ```

3. Add an RVM invocation and veewee alias to the end of your .profile or .bash_profile, .bashrc or .zshrc file, as follows:
    ```Shell
    if [[ -s $HOME/.rvm/scripts/rvm ]]; then
      source $HOME/.rvm/scripts/rvm;
    fi
    alias veewee='bundle exec veewee'
    ```

4. Install the appropriate version of Ruby:
    `rvm install ruby-1.9.2-p320`

5. Navigate to the veewee directory. This should automatically invoke RVM.

    `cd veewee`

    *NOTE:* If asked to upgrade from using an .rvmc file to a .ruby-version file, do *not* do this.

6. Copy or symlink the Seqware-veewee folder from SeqWare/vagrant into the veewee directory:
    `ln -s *[PATH TO BINDLE]*/SeqWare-veewee ./definitions/SeqWare-veewee`

7. Edit veewee's "definition.rb" file, and comment out the following three scripts:
    chef.sh, puppet.sh, ruby.sh


## Debugging

If you need to debug a problem set the VAGRANT_LOG variable e.g.:

    VAGRANT_LOG=DEBUG perl bin/launcher/launch_cluster.pl --use-aws

Also you can use the "--skip-launch" option to just create the various launch
files not actually trigger a VM.

Vagrant will often report an error (when using AWS of OpenStack) of the form
""Expected(200) <=> Actual(400 Bad Request)"." with no details.  See the
following patch for a fix to get more information:

https://github.com/jeremyharris/vagrant-aws/commit/1473c3a45570fdebed2f2b28585244e53345eb1d

## TODO

The list of TODO items, some of which are out-of-date.  See the
launch_cluster.pl script for more TODO items too.

* need to script the following for releasing AMIs: http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/building-shared-amis.html
* need to find way of displaying colour on stdout during Ansible play but suppress colour while saving to log
