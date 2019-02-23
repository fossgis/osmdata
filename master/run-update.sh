#!/bin/sh
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

set -x
set -e

iso_date='+%Y-%m-%dT%H:%M:%S'
STARTTIME=`date $iso_date`
LOGFILE=~/log/run-$STARTTIME.log

exec >$LOGFILE 2>&1

date

if [ "x$1" = "x-p" ]; then
    shift
else
    ~/osmdata/master/run-update-planet.sh </dev/null
fi

date

~/osmdata/master/run-update-osmdata.sh $* </dev/null

date

if [ -e /data/good/land-polygons-split-3857.zip ]; then
    if ~/osmdata/scripts/coastline/compare-coastline-polygons.sh /data/compare /data/new/land-polygons-split-3857.zip; then
        mv /data/new/* /data/good/
        cp /data/good/* /data/new/
    fi
fi

#------------------------------------------------------------------------------

# Remove old log files.
find ~/log -mtime +28 -type f -name 'run-*.log' -delete

date

echo "run-update done."

