#!/bin/bash
#
#  update-icesheet-zip.sh
#

set -euo pipefail
set -x

DATADIR=/home/robot/data/icesheet

iso_date='+%Y-%m-%dT%H:%M:%S'

echo "Started update-icesheet-zip.sh"
date $iso_date

cd $DATADIR

RESULTS=$DATADIR/results
mkdir -p $RESULTS

url_prefix='https://osmdata.openstreetmap.de/data'

for SHAPEDIR in antarctica-icesheet-* ; do
    test -d "$SHAPEDIR" || continue

    LAYERS=

    for SHP in $(find $SHAPEDIR -name '*.shp') ; do
        LN=$(basename "$SHP" .shp)
        echo "UTF-8" >"$SHAPEDIR/$LN.cpg"

        INFO=$(ogrinfo -so "$SHP" "$LN")

        EXT_INFO=$(echo "$INFO" | grep "^Extent: " | cut -d ":" -f 2-)
        XMIN=$(echo "$EXT_INFO" | cut -d "(" -f 2 | cut -d "," -f 1)
        YMIN=$(echo "$EXT_INFO" | cut -d "," -f 2 | cut -d ")" -f 1)
        XMAX=$(echo "$EXT_INFO" | cut -d "(" -f 3 | cut -d "," -f 1)
        YMAX=$(echo "$EXT_INFO" | cut -d "," -f 3 | cut -d ")" -f 1)

        P1=$(echo "$XMIN $YMIN" | gdaltransform -s_srs "EPSG:3857" -t_srs "EPSG:4326")
        P2=$(echo "$XMAX $YMAX" | gdaltransform -s_srs "EPSG:3857" -t_srs "EPSG:4326")
        LON_MIN=$(echo "$P1" | cut -d " " -f 1 | LC_ALL=C xargs /usr/bin/printf "%.3f" $p)
        LON_MAX=$(echo "$P2" | cut -d " " -f 1 | LC_ALL=C xargs /usr/bin/printf "%.3f" $p)
        LAT_MIN=$(echo "$P1" | cut -d " " -f 2 | LC_ALL=C xargs /usr/bin/printf "%.3f" $p)
        LAT_MAX=$(echo "$P2" | cut -d " " -f 2 | LC_ALL=C xargs /usr/bin/printf "%.3f" $p)

        XMIN=$(echo "($XMIN+0.5)/1" | bc)
        XMAX=$(echo "($XMAX+0.5)/1" | bc)
        YMIN=$(echo "($YMIN+0.5)/1" | bc)
        YMAX=$(echo "($YMAX+0.5)/1" | bc)

        FTYPE=$(echo "$INFO" | grep "^Geometry: " | cut -d ":" -f 2- | sed "s? ??g")
        FCOUNT=$(echo "$INFO" | grep "^Feature Count: " | cut -d ":" -f 2- | sed "s? ??g")

        LAYERS="$LAYERS\n\n$LN.shp:\n\n  $FCOUNT $FTYPE features\n  Mercator projection (EPSG: 3857)\n  Extent: ($XMIN, $YMIN) - ($XMAX, $YMAX)\n  In geographic coordinates: ($LON_MIN, $LAT_MIN) - ($LON_MAX, $LAT_MAX)"

    done

    YEAR=$(date '+%Y')
    DATE=$(date -r /mnt/data/planet/last-update +'%d %b %Y %H:%M')

    if echo "$SHAPEDIR" | grep "outline" > /dev/null ; then
        CONTENT="Antarctic icesheet outlines"
        URL=icesheet-outlines
    else
        CONTENT="Antarctic icesheet polygons"
        URL=icesheet-polygons
    fi

    sed -e "s?@YEAR@?${YEAR}?g;s?@URL@?${url_prefix}/${URL}.html?g;s?@DATE@?${DATE}?g;s?@CONTENT@?${CONTENT}?g" $BIN/README.tmpl | sed "/@LAYERS@/N;s?@LAYERS@?$LAYERS?" >"$SHAPEDIR/README"
    rm -f "$SHAPEDIR.zip.new"
    zip "$SHAPEDIR.zip.new" $SHAPEDIR/*
    mv "$SHAPEDIR.zip.new" "$SHAPEDIR.zip"
    mv "$SHAPEDIR.zip" "$RESULTS/$SHAPEDIR.zip"
done

echo "Done."
date $iso_date

