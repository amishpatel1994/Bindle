#!/bin/bash

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

groupadd -f $GROUP
id -u $USER &>/dev/null || useradd -g $GROUP $USER

## Now setup the master
if [ "%{HOST}" == "master" ]
then
  cp $SYSCONFDIR/mfsmaster.cfg.dist $SYSCONFDIR/mfsmaster.cfg
  cp $SYSCONFDIR/mfsmetalogger.cfg.dist $SYSCONFDIR/mfsmetalogger.cfg
  cp $SYSCONFDIR/mfsexports.cfg.dist $SYSCONFDIR/mfsexports.cfg

  cp $LOCALSTATEDIR/metadata.mfs.empty $LOCALSTATEDIR/metadata.mfs

  # Write mfsmaster.cfg - with interpolation, append
  cat << EOF >> $SYSCONFDIR/mfsmaster.cfg
WORKING_USER = $USER
WORKING_GROUP = $GROUP
DATA_PATH = $LOCALSTATEDIR
EOF

  chown -R $USER:$GROUP $LOCALSTATEDIR

  # Write mfsmaster boot script - part 1 - the header (no interpolation, overwrite)
  cat << 'EOF' > /etc/init.d/mfsmaster
#!/bin/sh

### BEGIN INIT INFO
# Provides:   mfs-master
# Required-Start: $network $remote_fs
# Required-Stop:  $remote_fs
# Default-Start:  2 3 4 5
# Default-Stop:   0 1 6
# Short-Description:  Start mfs-master at boot time
# Description:    mfs-master provides metadata management for MooseFS.
### END INIT INFO

EOF

  # Write mfsmaster boot script - part 2 - the settings (with interpolation, append)
  cat << EOF >> /etc/init.d/mfsmaster
PATH=$BINDIR:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
DAEMON=$BINDIR/mfsmaster
NAME=mfsmaster
DESC=mfs-master
DEFAULT_WORKING_USER=$USER
DEFAULT_WORKING_GROUP=$GROUP
DEFAULT_DATA_PATH=$LOCALSTATEDIR
DEFAULT_CFG=$SYSCONFDIR/mfsmaster.cfg
COMPAT_CFG=/etc/mfsmaster.cfg

EOF

  # Write mfsmaster boot script - part 3 - the body (no interpolation, append)
  cat << 'EOF' >> /etc/init.d/mfsmaster
test -e $DAEMON || exit 0

# Include mfs-master defaults if available
. /lib/lsb/init-functions
MFSMASTER_ENABLE=false
MFSMASTER_CONFIG_FILE=
MFSMASTER_DEFAULTS_FILE=/etc/default/mfs-master
if [ -s "$MFSMASTER_DEFAULTS_FILE" ]; then
    . "$MFSMASTER_DEFAULTS_FILE"
    case "x$MFSMASTER_ENABLE" in
        xtrue) ;;
        xfalse)
      log_warning_msg "mfs-master not enabled in \"$MFSMASTER_DEFAULTS_FILE\", exiting..."
      exit 0
      ;;
        *)
            log_failure_msg "value of MFSMASTER_ENABLE must be either 'true' or 'false';"
            log_failure_msg "not starting mfs-master."
            exit 1
            ;;
    esac
fi

set -e

if [ -n "$MFSMASTER_CONFIG_FILE" ]; then
  CFGFILE="$MFSMASTER_CONFIG_FILE"
elif [ -f "$DEFAULT_CFG" -o ! -f "$COMPAT_CFG" ]; then
  CFGFILE="$DEFAULT_CFG"
else
  CFGFILE="$COMPAT_CFG"
fi

get_config_value_from_CFGFILE()
{
    echo $(sed -e 's/[[:blank:]]*#.*$//' -n -e 's/^[[:blank:]]*'$1'[[:blank:]]*=[[:blank:]]*\(.*\)$/\1/p' $CFGFILE)
}

if [ -s "$CFGFILE" ]; then
  DATA_PATH=$(get_config_value_from_CFGFILE "DATA_PATH")
  WORKING_USER=$(get_config_value_from_CFGFILE "WORKING_USER")
  WORKING_GROUP=$(get_config_value_from_CFGFILE "WORKING_GROUP")
fi

: ${DATA_PATH:=$DEFAULT_DATA_PATH}
: ${WORKING_USER:=$DEFAULT_WORKING_USER}
: ${WORKING_GROUP:=$DEFAULT_WORKING_GROUP}

check_dirs()
{
  # check that the metadata dir exists
  if [ ! -d "$DATA_PATH" ]; then
    mkdir -p "$DATA_PATH"
  fi
  chmod 0755 "$DATA_PATH"
  chown -R $WORKING_USER:$WORKING_GROUP "$DATA_PATH"
  if [ ! -e "$DATA_PATH"/metadata.mfs ]; then
    if [ ! -e "$DATA_PATH"/metadata.mfs.back ]; then
      echo "MFSM NEW" > "$DATA_PATH"/metadata.mfs
    fi
  fi
}

case "$1" in
  start)
    check_dirs
    echo "Starting $DESC:"
    $DAEMON ${MFSMASTER_CONFIG_FILE:+-c $MFSMASTER_CONFIG_FILE} $DAEMON_OPTS start
    ;;

  stop)
    echo "Stopping $DESC:"
    $DAEMON ${MFSMASTER_CONFIG_FILE:+-c $MFSMASTER_CONFIG_FILE} stop
    ;;

  reload|force-reload)
    echo "Reloading $DESC:"
    $DAEMON ${MFSMASTER_CONFIG_FILE:+-c $MFSMASTER_CONFIG_FILE} reload
    ;;

  restart)
    check_dirs
    echo "Restarting $DESC:"
    $DAEMON ${MFSMASTER_CONFIG_FILE:+-c $MFSMASTER_CONFIG_FILE} restart
    ;;

  *)
    N=/etc/init.d/$NAME
    echo "Usage: $N {start|stop|restart|force-reload}" >&2
    exit 1
    ;;
esac

exit 0
EOF

  chmod a+x /etc/init.d/mfsmaster
  update-rc.d mfsmaster defaults
  /etc/init.d/mfsmaster start
fi
