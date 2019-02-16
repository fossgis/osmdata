#!/bin/sh
#
#  run-update.sh [-p]
#
#  Run data update job. This will update the planet file and then do various
#  data exports. Use "-p" to not do the planet update.
#

if [ "$USER" != "robot" ]; then
    echo "Must be run as user robot"
    exit 1
fi

set -x
set -e

iso_date='+%Y-%m-%dT%H:%M:%S'
STARTTIME=`date $iso_date`
LOGFILE=~/log/run-$STARTTIME.log

exec >$LOGFILE 2>&1

if [ "x$1" != "x-p" ]; then
    ~/osmdata/master/run-update-planet.sh </dev/null
fi

~/osmdata/master/run-update-osmdata.sh </dev/null

if [ -e /data/checked/land-polygons-split-3857.zip ]; then
    if ~/osmdata/scripts/coastline/compare-coastline-polygons.sh /data/compare /data/results/land-polygons-split-3857.zip; then
        mv /data/results/* /data/checked/
        cp /data/checked/* /data/results/
    fi
fi

