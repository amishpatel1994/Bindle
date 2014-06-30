#!/bin/bash

# Fail for now
exit 1

# Build and install moosefs

## Use on all machines to build a basic setup
apt-get update
apt-get -q -y --force-yes install build-essential pkg-config libfuse-dev zlib1g-dev

wget -O /tmp/mfs-1.6.27-5.tar.gz http://sourceforge.net/projects/moosefs/files/moosefs/1.6.27/mfs-1.6.27-5.tar.gz
cd /tmp
tar xf /tmp/mfs-1.6.27-5.tar.gz
cd /tmp/mfs-1.6.27

./configure
make && make install

BINDIR=/usr/local/sbin
SYSCONFDIR=/usr/local/etc/mfs
LOCALSTATEDIR=/usr/local/var/mfs
USER=mfs
GROUP=mfs

## Now setup the master
if [ "%{HOST}" -eq "master" ]
then
  cp $SYSCONFDIR/mfsmaster.cfg.dist $SYSCONFDIR/mfsmaster.cfg
  cp $SYSCONFDIR/mfsmetalogger.cfg.dist $SYSCONFDIR/mfsmetalogger.cfg
  cp $SYSCONFDIR/mfsexports.cfg.dist $SYSCONFDIR/mfsexports.cfg

  cp $LOCALSTATEDIR/metadata.mfs.empty $LOCALSTATEDIR/metadata.mfs

  #TODO: Configure mfsmaster.cfg
  #if grep -q '^WORKING_USER = ' $SYSCONFDIR/mfsmaster.cfg

  chown -R $USER:$GROUP $LOCALSTATEDIR

  #TODO: Write mfsmaster boot script

  update-rc.d mfsmaster defaults
  /etc/init.d/mfsmaster start
fi