use strict;
use Getopt::Long;

# PURPOSE:
# This script attempts to format, mount, and encrypt all the volumes available . You
# will be left with various devices mounted as /mnt/<devname>/ with a directory
# called /mnt/<devname>/encrypted under which anything written will be
# encrypted using ecryptfs with a random key. Anything outside of this
# directory will not be encrypted. If ecryptfs is not installed the encrypted
# directory is not created.
# ASSUMPTIONS:
# * this script does not setup HDFS or Gluster
# * you have ecryptfs and mkfs.xfs installed
# TODO

my $final_list;
my $out_file = "mount_report.txt";
my $list = `ls -1 /dev/sd* /dev/xv*`;
my @list = split /\n/, $list;
my $whitelist;
my @wlist = {};
my $gluster_directory_list;
my @dir_list = {};
GetOptions (
  "output=s" => \$out_file,
  "whitelist=s" => \$whitelist,
  "directorylist=s" => \$gluster_directory_list,
);


# MAIN LOOP

@wlist = read_list($whitelist);
@dir_list = read_list($gluster_directory_list);

foreach my $dev (@list) {
  # skip if doesn't exist
  next if (!-e $dev || -l $dev);
  print "All Devices: $dev\n";
  # true if empty or it's on the whitelist
  next if (!whitelist($dev, @wlist));
  # then extra device so can continue
  print "DEV: $dev\n";
  # if already mounted just add directory
  if(!mounted($dev)) {
    print " NOT MOUNTED!\n";
    my $format = system("bash -c 'mkfs.xfs -i size=512 $dev &> /dev/null'");
    if ($format) { print " UNABLE TO FORMAT!\n"; }
    else { print " FORMATTED OK!\n"; }
    $dev =~ /\/dev\/(\S+)/;
    my $dev_name = $1;
    print " MOUNTING BECAUSE NOT MOUNTED\n";
    my $mount = system("bash -c 'mkdir -p /$dev_name && mount $dev /$dev_name' && chmod a+rwx /$dev_name");
    if ($mount) { print " UNABLE TO MOUNT $dev on /$dev_name\n"; }
  } else {
    print " NOT MOUNTING SINCE ALREADY MOUNTED!\n";
  }
  my $mount_path = find_mount_path($dev);
  # if ecryptfs was success, the mount path gets encrypted added to it
  if(setup_ecryptfs($mount_path)) {
    $mount_path = $mount_path."/encrypted";
  }
  # add to the list of mounted dirs
  $final_list .= "$mount_path\n";
}

# now handle the list of dirs
# for each dir in list
# do setup_ecrypt
# add to final_list
foreach my $dir (@dir_list) {
  my $mount_path = $dir;
  if (setup_ecryptfs($mount_path)) {
    $mount_path = $mount_path."/encrypted";
  }
  $final_list .= "$mount_path\n";
}

# OUTPUT REPORT

open OUT, ">$out_file" or die "Can't open output file $out_file\n";
print OUT $final_list;
close OUT;


# SUBROUTINES

# separates the string into an array 
sub read_list {
  my ($data) = @_;
  my @list = split /,/, $data;
  return @list;
}

# determines if the device is permitted to be used as a volume
sub whitelist {
  my ($dev, @whlist) = @_;
  if (scalar(@whlist) == 0){
    print "WARNING: USING ALL THE DEVICES TO SET UP VOLUMES!!!! YOU DIDN'T SPECIFY ANY WHITELIST DEVICES!!!!\n";
    return 1;
  }
  else{ 
    foreach(@whlist) {
      print "DEV $dev\n";
      my ($option1,$option2,$option3) = ("/dev/sd$_", "/dev/hd$_","/dev/xvd$_");
      print "option1 $option1\n";
      if ($dev =~ m/^($option1|$option2|$option3)$/i){
        print " WHITELIST DEV $dev\n";
        return 1;
      }
    }
  }
  return 0;
}

sub mounted {
  my $dev = shift;
  # blacklist any drives that are likely to be root partition
  if ($dev =~ /sda/ || $dev =~ /hda/ || $dev =~ /xvda/) {
    print " DEV BLACKLISTED: $dev\n";
    return(1);
  }
  my $count = `df -h | grep $dev | wc -l`;
  chomp $count;
  return($count);
}

sub add_to_config {
  my $path = shift;
  if (-e "/etc/hadoop/conf/hdfs-site.xml") {
         open CONF, "</etc/hadoop/conf/hdfs-site.xml";
         my $newfile = "";
         while(<CONF>) {
          chomp;
          $_ =~ s/file:\/\/\/var\/lib\/hadoop-hdfs\/cache\/\$\{user.name\}\/dfs\/data/file:\/\/\/var\/lib\/hadoop-hdfs\/cache\/\$\{user.name\}\/dfs\/data,file:\/\/$path/g;
          $newfile .= "$_\n";
         }
         close CONF;
         system("bash -c 'cp /etc/hadoop/conf/hdfs-site.xml /etc/hadoop/conf/hdfs-site.dist'");
         open CONF, ">/etc/hadoop/conf/hdfs-site.xml";
         print CONF $newfile;
         close CONF;
       } else {
         print " ERROR: can't find /etc/hadoop/conf/hdfs-site.xml\n";
       }
}

sub setup_ecryptfs {
  my ($dir) = @_;
  my $ecrypt_result;
  # attempt to find this tool
  my $result = system("which mount.ecryptfs");
  if ($result == 0) {
    my $found = `mount | grep $dir/encrypted | grep 'type ecryptfs' | wc -l`;
    chomp $found;
    if ($found =~ /0/) {
      my @chars = ( "A" .. "Z", "a" .. "z", 0 .. 9 );
      my $password = join("", @chars[ map { rand @chars } ( 1 .. 11 ) ]);
      my $ecrypt_cmd = "mkdir -p $dir/encrypted && mount.ecryptfs $dir/encrypted $dir/encrypted -o ecryptfs_cipher=aes,ecryptfs_key_bytes=16,ecryptfs_passthrough=n,ecryptfs_enable_filename_crypto=n,no_sig_cache,key=passphrase:passwd=$password && chmod a+rwx $dir/encrypted";
      $ecrypt_result = system($ecrypt_cmd);
      if ($ecrypt_result) {
         print " ERROR: there was a problem running the ecrypt command $ecrypt_cmd\n";
         return(0);
      }
    } else {
      print " ALREADY ENCRYPTED: this was already encrypted $dir so skipping.\n";
    }
  } else {
    print " ERROR: can't find mount.ecryptfs so skipping encryption of the HDFS volume\n";
    return(0);
  }
  return(1);
}

sub find_mount_path {
  my $dev = shift;
  my $path = `df -h | grep $dev | awk '{ print \$6}'`;
  chomp $path;
  return($path);
}
