#!/bin/bash
#------------------------------------------------------------------------------
#
#  planet/update.sh
#
#------------------------------------------------------------------------------

set -euo pipefail
set -x

iso_date='+%Y-%m-%dT%H:%M:%S'

DATADIR=/mnt/data/planet

PLANET=$DATADIR/planet.osm.pbf
NEW_PLANET=$DATADIR/new-planet.osm.pbf
OLD_PLANET=$DATADIR/old-planet.osm.pbf

COASTLINES=$DATADIR/coastlines.osm.pbf
NEW_COASTLINES=$DATADIR/new-coastlines.osm.pbf

ANT=$DATADIR/antarctica.osm.pbf
NEW_ANT=$DATADIR/new-antarctica.osm.pbf

ANT_COASTLINES=$DATADIR/antarctica-coastlines.osm.pbf
NEW_ANT_COASTLINES=$DATADIR/new-antarctica-coastlines.osm.pbf

mkdir -p $DATADIR

rm -f $OLD_PLANET

date $iso_date

echo "Downloading planet file (if there isn't one)..."
test -f $PLANET || wget --no-verbose -O $PLANET https://planet.openstreetmap.org/pbf/planet-latest.osm.pbf

date $iso_date

echo "Updating planet file..."
rm -f $NEW_PLANET
export OSMIUM_POOL_THREADS=7
/usr/lib/python3-pyosmium/pyosmium-up-to-date -v --size 5000 -o $NEW_PLANET $PLANET
mv $PLANET $OLD_PLANET
mv $NEW_PLANET $PLANET

osmium fileinfo -g header.option.osmosis_replication_timestamp $PLANET >$DATADIR/last-update

date $iso_date

echo "Filtering coastlines..."
rm -f $NEW_COASTLINES
osmcoastline_filter --verbose --output=$NEW_COASTLINES $PLANET
mv $NEW_COASTLINES $COASTLINES

date $iso_date

echo "Extracting Antarctica..."
rm -f $NEW_ANT
osmium extract --verbose --strategy=simple --bbox=-180,-90,180,-60 --fsync --overwrite --output=$NEW_ANT $PLANET
mv $NEW_ANT $ANT

date $iso_date

echo "Filtering Antarctica coastlines..."
rm -f $NEW_ANT_COASTLINES
osmcoastline_filter --verbose --output=$NEW_ANT_COASTLINES $ANT
mv $NEW_ANT_COASTLINES $ANT_COASTLINES

date $iso_date

df -h

