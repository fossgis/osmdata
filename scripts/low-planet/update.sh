#!/bin/bash
#------------------------------------------------------------------------------
#
#  low-planet/update.sh
#
#------------------------------------------------------------------------------

iso_date='+%Y-%m-%dT%H:%M:%S'

set -x
set -e

DATADIR=/mnt/data/planet

PLANET=$DATADIR/planet.osm.pbf
LOW_PLANET=$DATADIR/low-planet.osm.pbf

NEW_LOW_PLANET=$DATADIR/new-low-planet.osm.pbf

mkdir -p $DATADIR

date $iso_date

echo "Removing leftover partial low planet (if any)..."
rm -f $NEW_LOW_PLANET

echo "Removing existing low planet (if any)..."
rm -f $LOW_PLANET

echo "Creating low planet from planet..."
osmium add-locations-to-ways \
    --verbose \
    --keep-untagged-nodes \
    --index-type=dense_mmap_array \
    --fsync \
    --output=$NEW_LOW_PLANET $PLANET \
    && mv $NEW_LOW_PLANET $LOW_PLANET

date $iso_date

df -h

