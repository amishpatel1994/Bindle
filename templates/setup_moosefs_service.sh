#!/bin/bash

# PURPOSE:
# This script attempts to start the moosefs volume
# ASSUMPTIONS:
# * only run on the master node
# * arguments in --host=..., --dir-map=...
# TODO
# * 

BINDIR=/usr/local/sbin
SYSCONFDIR=/usr/local/etc/mfs
LOCALSTATEDIR=/usr/local/var/mfs
USER=mfs
GROUP=mfs

for i in "$@"
do
case $i in
    --host=*)
    HOST="${i#*=}"
    shift
    ;;
    --dir-map=*)
    DIRMAP="${i#*=}"
    shift
    ;;
    --default)
    DEFAULT=YES
    shift
    ;;
    *)
            # unknown option
    ;;
esac
done

### Now we set up the chunkservers.

cp $SYSCONFDIR/mfschunkserver.cfg.dist $SYSCONFDIR/mfschunkserver.cfg
cp $SYSCONFDIR/mfshdd.cfg.dist $SYSCONFDIR/mfshdd.cfg

# Write mfschunkserver.cfg - with interpolation, append
cat << EOF >> $SYSCONFDIR/mfschunkserver.cfg
WORKING_USER = $USER
WORKING_GROUP = $GROUP
MASTER_HOST = master
DATA_PATH = $LOCALSTATEDIR
EOF

# Configure mfshdd.cfg, but only for this server 
while read line
do
	record=($line)
	host = ${record[0]}
	directory = ${record[1]}
	if [ "$host" == "%{HOST}" ]; then
		chown -R $USER:$GROUP $directory
		echo $directory >> $SYSCONFDIR/mfshdd.cfg
	fi
done < $DIRMAP

# Write mfschunkserver boot script - part 1 - the header (no interpolation, overwrite)
cat << 'EOF' > /etc/init.d/mfschunkserver
#!/bin/sh

### BEGIN INIT INFO
# Provides:   mfs-chunkserver
# Required-Start: $network $remote_fs
# Required-Stop:  $remote_fs
# Default-Start:  2 3 4 5
# Default-Stop:   0 1 6
# Short-Description:  Start mfs-chunkserver at boot time
# Description:    mfs-chunkservers provide storage space for MooseFS.
### END INIT INFO

EOF

# Write mfschunkserver boot script - part 2 - the variables (interpolation, append)
cat << EOF >> /etc/init.d/mfschunkserver
PATH=$BINDIR:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
DAEMON=$BINDIR/mfschunkserver
NAME=mfschunkserver
DESC=mfs-chunkserver
DEFAULT_WORKING_USER=$USER
DEFAULT_WORKING_GROUP=$GROUP
DEFAULT_DATA_PATH=$LOCALSTATEDIR
DEFAULT_CFG=$SYSCONFDIR/mfschunkserver.cfg
COMPAT_CFG=/etc/mfschunkserver.cfg

EOF

# Write mfschunkserver boot script - part 3 - the body (no interpolation, append)
cat << 'EOF' >> /etc/init.d/mfschunkserver
test -e $DAEMON || exit 0

# Include mfs-chunkserver defaults if available
. /lib/lsb/init-functions
MFSCHUNKSERVER_ENABLE=false
MFSCHUNKSERVER_DEFAULTS_FILE=/etc/default/mfs-chunkserver
MFSCHUNKSERVER_CONFIG_FILE=
if [ -s "$MFSCHUNKSERVER_DEFAULTS_FILE" ]; then
    . "$MFSCHUNKSERVER_DEFAULTS_FILE"
    case "x$MFSCHUNKSERVER_ENABLE" in
        xtrue) ;;
        xfalse)
      log_warning_msg "mfs-chunkserver not enabled in \"$MFSCHUNKSERVER_DEFAULTS_FILE\", exiting..."
      exit 0
      ;;
        *)
            log_failure_msg "value of MFSCHUNKSERVER_ENABLE must be either 'true' or 'false';"
            log_failure_msg "not starting mfs-chunkserver."
            exit 1
            ;;
    esac
fi

set -e

if [ -n "$MFSCHUNKSERVER_CONFIG_FILE" ]; then
  CFGFILE="$MFSCHUNKSERVER_CONFIG_FILE"
elif [ -f "$DEFAULT_CFG" -o ! -f "$COMPAT_CFG" ]; then
  CFGFILE="$DEFAULT_CFG"
else
  CFGFILE="$COMPAT_CFG"
fi
if [ -s "$CFGFILE" ]; then
  DATADIR=$(sed -e 's/[   ]#.*$//' -n -e 's/^DATA_PATH[   ]*=[  ]*\([^  ]*\)[   ]*$/\1/p' "$CFGFILE")
  MFSUSER=$(sed -e 's/[   ]#.*$//' -n -e 's/^WORKING_USER[  ]*=[  ]*\([^  ]*\)[   ]*$/\1/p' "$CFGFILE")
  MFSGROUP=$(sed -e 's/[  ]#.*$//' -n -e 's/^WORKING_GROUP[   ]*=[  ]*\([^  ]*\)[   ]*$/\1/p' "$CFGFILE")
else
  DATADIR=
  MFSUSER=
  MFSGROUP=
fi
: ${DATADIR:=$DEFAULT_DATADIR}
: ${MFSUSER:=$DEFAULT_USER}
: ${MFSGROUP:=$DEFAULT_GROUP}

check_dirs()
{
  # check that the metadata dir exists
  if [ ! -d "$DATADIR" ]; then
    mkdir "$DATADIR"
  fi
  chmod 0755 "$DATADIR"
  chown -R $MFSUSER:$MFSGROUP "$DATADIR"
}

case "$1" in
  start)
    check_dirs
    echo "Starting $DESC:"
    $DAEMON ${MFSCHUNKSERVER_CONFIG_FILE:+-c $MFSCHUNKSERVER_CONFIG_FILE} $DAEMON_OPTS start
    ;;

  stop)
    echo "Stopping $DESC:"
    $DAEMON ${MFSCHUNKSERVER_CONFIG_FILE:+-c $MFSCHUNKSERVER_CONFIG_FILE} stop
    ;;

  reload|force-reload)
    echo "Reloading $DESC:"
    $DAEMON ${MFSCHUNKSERVER_CONFIG_FILE:+-c $MFSCHUNKSERVER_CONFIG_FILE} reload
    ;;

  restart)
    echo "Restarting $DESC:"
    $DAEMON ${MFSCHUNKSERVER_CONFIG_FILE:+-c $MFSCHUNKSERVER_CONFIG_FILE} $DAEMON_OPTS restart
    ;;

  *)
    N=/etc/init.d/$NAME
    echo "Usage: $N {start|stop|restart|reload|force-reload}" >&2
    exit 1
    ;;
esac

exit 0
EOF

### Now the /etc/init.d file has been written. We can continue. 

chmod a+x /etc/init.d/mfschunkserver
update-rc.d mfschunkserver defaults
/etc/init.d/mfschunkserver start
