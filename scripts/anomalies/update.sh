#!/bin/bash
#------------------------------------------------------------------------------
#
#  anomalies/update.sh
#
#------------------------------------------------------------------------------

set -euo pipefail
set -x

iso_date='+%Y-%m-%dT%H:%M:%S'

DATADIR=/tmp/anomalies
PLANETDIR=/mnt/data/planet
ANOMALDIR=/mnt/data/anomalies

PLANET=$PLANETDIR/planet.osm.pbf
LOW_PLANET=$PLANETDIR/low-planet.osm.pbf

mkdir -p $DATADIR

date $iso_date

export OSMIUM_POOL_THREADS=3
for prog in ~/anomalies/odad-find-*; do
    $prog $LOW_PLANET $DATADIR
done

date $iso_date

df -h

