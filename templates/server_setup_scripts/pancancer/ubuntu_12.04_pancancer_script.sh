# a place for PanCancer specific config

# general apt-get
apt-get update
export DEBIAN_FRONTEND=noninteractive

# general items needed for bwa workflow
apt-get -q -y --force-yes install liblz-dev zlib1g-dev libxml-dom-perl samtools libossp-uuid-perl libjson-perl libxml-libxml-perl libtry-tiny-perl libgd2-noxpm g++  dh-autoreconf libncurses-dev pkg-config libgd2-noxpm-dev libgd2-noxpm libxml-xpath-perl 

# download public key
if [ ! -e "cghub_public.key" ]; then
  wget https://cghub.ucsc.edu/software/downloads/cghub_public.key
fi

# dependencies for genetorrent
apt-get -q -y --force-yes install libboost-filesystem1.48.0 libboost-program-options1.48.0 libboost-regex1.48.0 libboost-system1.48.0 libicu48 libxerces-c3.1 libxqilla6
perl -pi -e 'print "deb http://cz.archive.ubuntu.com/ubuntu precise main universe" if $. == 1' /etc/apt/sources.list
sudo apt-get update
sudo apt-get -f --force-yes install
cd /tmp
wget http://cghub.ucsc.edu/software/downloads/GeneTorrent/3.8.5/genetorrent-common_3.8.5-ubuntu2.91-12.04_amd64.deb
wget http://cghub.ucsc.edu/software/downloads/GeneTorrent/3.8.5/genetorrent-download_3.8.5-ubuntu2.91-12.04_amd64.deb
wget http://cghub.ucsc.edu/software/downloads/GeneTorrent/3.8.5/genetorrent-upload_3.8.5-ubuntu2.91-12.04_amd64.deb
# finally install these
dpkg -i genetorrent-common_3.8.5-ubuntu2.91-12.04_amd64.deb genetorrent-download_3.8.5-ubuntu2.91-12.04_amd64.deb genetorrent-upload_3.8.5-ubuntu2.91-12.04_amd64.deb
cd -
