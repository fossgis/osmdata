#!/bin/sh
#
#  release-coastline.sh
#

cd /data/compare

NEWEST=`ls mask-20* | tail -1`

rm -f mask-good.tiff
ln -s $NEWEST mask-good.tiff

mv /data/new/* /data/good/
cp /data/good/* /data/new/

