use strict;
use Getopt::Long;

# PURPOSE:
# This script attempts to configure directories for sharing via moosefs
# ASSUMPTIONS:
# * the EBS/ephemeral disks have all been formated with xfs and mounted
# * this just creates a moosefs directory on every specified directory and writes it out to a new file
# TODO
# * 

exit(1);

my $dir_map;
my $output;

GetOptions (
  "dir-map=s" => \$dir_map,
  "output=s" => \$output,
);

my $vol_report = `cat /vagrant/volumes_report.txt`;
# if there are no volumes present, don't set up distributed file volumes!
if ($vol_report eq ""){
  print "Not Setting up moosefs volumes because no moosefs devices/directory were specified in the config file!\n";
  exit;
}

my $out_txt;

open IN, "<", $dir_map or die "Cannot open file $dir_map: $!\n";
open OUT, ">", $output or die "Cannot open file $output: $!\n";
while(<IN>) {
  chomp;
  my $location = $_;
  $location = "$location/moosefs";
  if (system("mkdir -p $location")) {
    print "Problems creating directory $location\n";
  }
  $out_txt .= "$location\n";
}
print OUT $out_txt;
close OUT;
close IN;
