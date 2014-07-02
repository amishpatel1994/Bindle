use common::sense;
use Config::Simple;
use Data::Dumper;
use Getopt::Long;

my $config_file;
my $use_cluster = 0;
my $use_node = 0;
my $launch_bionimbus = 0;
my $cluster_name;
my $help = 0;

GetOptions( "config-file=s"   	=> \$config_file,
	    "use-single-node" 	=> \$use_node,
	    "use-multi-node"	=> \$use_cluster,
	    "for-bionimbus"	=> \$launch_bionimbus,
	    "cluster-name=s"	=> \$cluster_name,
 	    "help"		=> \$help );

die "USAGE: 'perl config_file_validator.pl --use-single-node|--use-multi-node --config-file <sample.cfg> --cluster-name <cluster1> [--for-bionimbus]\n\t--use-single-node\tflag to indicate that you will be launching a single-node cluster\n\t--use-multi-node\tflag to indicate that you will be launching a multi-node cluster\n\t--config-file\t\tthe config file which needs validation\n\t--cluster-name\t\tcluster block inside the config file which you will be using to launch a cluster\n\t--for-bionimbus\t\tflag to indicate that you are using the bionimbus environment to launch clusters" if ($help);

die "'--config-file <sample.cfg>' parameter is required when you are calling this script!" unless (defined $config_file);
die "'--cluster-name <clusterblock>' parameter is required when you are calling this script!" unless (defined $cluster_name);
die "Either '--use-single-node' or '--use-multi-node' must be included!" unless($use_cluster xor $use_node);

my $configs = new Config::Simple($config_file);
my $actual_type = uc((split /\./, $config_file)[0]);

say "\n\t\t\t\tPLATFORM VALIDATION";
say "--------------------------------------------------------------------------------\n";

say "FIX: Fill in the <fillmein> parts!" if (Dumper($configs->param(-block => "platform")) =~ /<fillmein>/);
say "FIX: Please change the type param under platform to $actual_type" if ($configs->param('platform.type') ne $actual_type);
say "FIX: Invalid ssh_key_name. Please get rid of '.pem' extension and only include the key's name!" if ($configs->param('platform.ssh_key_name') =~ /\.pem$/);

validate_distributed_file_info($configs->param('platform.distributed_file_device_whitelist'),$configs->param('platform.distributed_file_directory_path'));

say "Finished Platform Validation";
say "\n\t\t\tCLUSTER BLOCK VALIDATION FOR $cluster_name";
say "--------------------------------------------------------------------------------\n";

validate_single_node_config($configs->param(-block => "$cluster_name")) if ($use_node);

validate_multi_node_config($configs->param(-block => "$cluster_name")) if ($use_cluster);

say "Finished Cluster Validation";






# subroutines

sub validate_distributed_file_info {
  my ($distributed_file_device_whitelist,$distributed_file_directory) = @_;

  # cluster for other environments
  if ($use_cluster && !$launch_bionimbus){
    say "FIX: Please fill in distributed_file_device_whitelist or distributed_file_directory_path" if ($distributed_file_device_whitelist eq "" && $distributed_file_directory eq "");
    say "FIX: Don't use 'a or a1' as your distributed file device since 'sda','xvda',etc. are mounted at root" if ($distributed_file_device_whitelist =~ /a|a[0-9]/);
    say "FIX: Change the format for distributed_file_device_whitelist('--whitelist b,c,d')" unless ($distributed_file_device_whitelist =~ /^--whitelist [bcdef]/);
    say "FIX: Don't include spaces between your list for distributed_file_device_whitelist('--whitelist b,c,d')" if ($distributed_file_device_whitelist =~ /, /);
    say "FIX: Change the format for distributed_file_directory_path('--directorypath /mnt/vols/gluster') and only include one path!" unless  ($distributed_file_directory =~ /^--directorypath \//);
    say "FIX: Only include one directory for distributed_file_directory_path(Ex. '--directorypath /mnt/vols/gluster')" if ($distributed_file_directory =~ /,/);
  }
  # validation for single node clusters and bionimbus clusters
  else{
      say "FIX: Leave distributed_file_device_whitelist and distributed_file_directory_path values empty ('') because you don't need it!!" unless ($distributed_file_device_whitelist eq "" &&  $distributed_file_directory eq "");
  }

}

# validates the single node cluster block 
sub validate_single_node_config {
  my ($block) = @_;
  say "FIX: Fill in the <fillmein> parts!" if (Dumper($block) =~ /<fillmein>/);
  say "FIX: Set 'number_of_nodes' to 1 since you are launching a single node!" if ($block->{number_of_nodes} != 1);
  say "FIX: Please fill in the target_firectory!(Ex. target-os-2)" unless (defined $block->{target_directory});
  say "FIX: Change the json template file path to a node specific template! (Ex: templates/sample_configs/vagrant_cluster_launch.pancancer.bwa_workflow.seqware.install.sge_node.json.template)" if ($block->{json_template_file_path} =~ /sge_cluster/);
  say "FIX: floating_ips can't have letters.(Ex. 10.0.20.175)" if (defined $block->{floating_ips} && $block->{floating_ips}[0] =~ /[^0-9.]/);
}

# validates the cluster block for a multi-node cluster
sub validate_multi_node_config {
  my ($block) = @_;
  say "FIX: Fill in the <fillmein> parts!" if (Dumper($block) =~ /<fillmein>/);
  say "FIX: 'number_of_nodes' must be an natural number greater than 1!" unless ($block->{number_of_nodes} >= 2 );
  say "FIX: Change the json template file path to a cluster specific template! (Ex: vagrant_cluster_launch.pancancer.seqware.install.sge_cluster.json.template)" if ($block->{json_template_file_path} =~ /sge_node/);
  say "FIX: Please fill in the target_firectory!(Ex. target-os-2)" unless (defined $block->{target_directory});
  if (defined $block->{floating_ips}){
    say "FIX: floating_ips have to be a list (Ex. '10.0.20.145,10.0.20.156')" unless ($block->{floating_ips} =~ /ARRAY/);
    foreach (my $count = 0; $count < $block->{number_of_nodes}; $count++){
      say "FIX: floating_ips can't have letters!" if ($block->{floating_ips}[$count] =~ /[^0-9.]/);
    }
  }
} 
