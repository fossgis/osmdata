#!/bin/bash
#
#  run-update.sh [-p] [JOBS...]
#
#  Run data update job. This will update the planet file and then do various
#  data exports. Use "-p" to not do the planet update.
#
#  If JOBS isn't used, all jobs will be run, otherwise only the specified
#  jobs will be run.
#
#  run-update.sh                    -- Update planet, run all jobs
#  run-update.sh -p                 -- Do not update planet, run all jobs
#  run-update.sh coastline          -- Update planet, run only coastline job
#  run-update.sh coastline icesheet -- Update planet, run coastline and icesheet jobs
#

if [ "$USER" != "robot" ]; then
    echo "Must be run as user robot"
    exit 1
fi

set -e

iso_date='+%Y-%m-%dT%H:%M:%S'
STARTTIME=$(date $iso_date)
LOGFILE=~/log/run-$STARTTIME.log
LOCK_FILE=~/log/running

exec >$LOGFILE 2>&1

echo $iso_date >$LOCK_FILE

date

if [ "x$1" = "x-p" ]; then
    shift
else
    echo "Running planet update..."
    ~/osmdata/master/run-update-planet.sh </dev/null
fi

date

#echo "Running low-planet update..."
#~/osmdata/master/run-update-low-planet.sh $* </dev/null

echo "Running osmdata update..."
~/osmdata/master/run-update-osmdata.sh $* </dev/null

#echo "Running anomalies update..."
#~/osmdata/master/run-update-anomalies.sh $* </dev/null

sync

date

if [ -e /data/good/land-polygons-split-3857.zip ]; then
    echo "Found good land-polygons-split-3857.zip, comparing new one with it..."
    if ~/osmdata/scripts/coastline/compare-coastline-polygons.sh /data/compare /data/new/land-polygons-split-3857.zip; then
        echo "New one is okay, use it..."
        mv /data/new/* /data/good/
        sync
        cp /data/good/* /data/new/
        sync
    fi
fi

rm -f $LOCK_FILE

#------------------------------------------------------------------------------

# Remove old log files.
echo "Removing old log files..."
find ~/log -mtime +28 -type f -name 'run-*.log' -delete

date

echo "run-update done."

