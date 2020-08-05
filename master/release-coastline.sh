#!/bin/sh
#
#  release-coastline.sh
#

LOCK_FILE=~/log/running

if [ -f $LOCK_FILE ]; then
    echo "Update process is running. Can not release coastline."
    exit 1
fi

date >>~/log/release-coastline.log

cd /data/compare

NEWEST=`ls mask-20* | tail -1`

rm -f mask-good.tiff
ln -s $NEWEST mask-good.tiff

mv /data/new/* /data/good/
cp /data/good/* /data/new/

