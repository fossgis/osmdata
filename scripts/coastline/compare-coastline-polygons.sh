#!/bin/bash
#------------------------------------------------------------------------------
#
#  compare_coastline_polygons DIR SOURCE
#
#  to reset remove symlink $DIR/mask-good.tiff
#
#------------------------------------------------------------------------------

set -euo pipefail
set -x

DIFF_MAXIMUM=0.0000015

DIR="$1"
WEBDIR="/data/web/coastline"
SOURCE="$2"
STARTTIME_COMPACT=$(date '+%Y%m%dT%H%M%S')

test \! -z "$DIR"
test \! -z "$SOURCE"

GOOD=$DIR/mask-good.tiff
NEW=$DIR/mask-$STARTTIME_COMPACT.tiff

rm -fr "$DIR/land-polygons-split-3857"

unzip "$SOURCE" -d "$DIR"

# limit growth of differences file
if [ -f "$DIR/differences" ]; then
    tail -100 "$DIR/differences" >"$DIR/differences.new"
    mv "$DIR/differences.new" "$DIR/differences"
fi

gdal_rasterize -q --config GDAL_CACHEMAX 1024 "$DIR/land-polygons-split-3857" -l land_polygons \
    -te -20037508.342789244 -20037508.342789244 20037508.342789244 20037508.342789244 \
    -init 0 -burn 255 -ts 8192 8192 -ot Byte -co COMPRESS=DEFLATE \
    "$NEW"

rm -f "$DIR/mask-new.tiff"
ln -s "$NEW" "$DIR/mask-new.tiff"

rm -fr "$DIR/land-polygons-split-3857"

#------------------------------------------------------------------------------

# generate a "diff" image for human consumption
rm -f "$DIR/mask-diff.tiff"

if [ -e "$GOOD" ]; then
    gdal_calc.py -A "$GOOD" \
                 -B "$NEW" \
                 --quiet \
                 --NoDataValue=0 --type=Byte --co=COMPRESS=DEFLATE \
                 --outfile="$DIR/mask-diff.tiff" --calc="(A!=B)*255"
fi

#------------------------------------------------------------------------------

for img in good new diff; do
    mkdir -p "$WEBDIR/$img"
    if [ -e "$DIR/mask-$img.tiff" ]; then
        gdal2tiles.py --webviewer none -z 0-6 "$DIR/mask-$img.tiff" "$WEBDIR/$img"
    fi
done

#------------------------------------------------------------------------------

if [ ! -r "$NEW" ]; then
    echo "$STARTTIME_COMPACT: 0:0.0:0:0.0:0:0.0:0:0.0:0.0:0.0 ERROR" >>"$DIR/differences"
    echo "stopping coastline processing due to raster mask generation error."
    exit 1
fi

#------------------------------------------------------------------------------

if [ ! -h "$GOOD" ]; then
    ln -s "$NEW" "$GOOD"
    echo "$STARTTIME_COMPACT: 0:0.0:0:0.0:0:0.0:0:0.0:0.0:0.0 OK" >>"$DIR/differences"
    exit 0
fi

#------------------------------------------------------------------------------

DIFFERENCES=$(gdal_maskcompare_wm "$GOOD" "$NEW" 20000 | grep 'short version:')
DIFF_RATING=$(echo "$DIFFERENCES" | cut -d ':' -f 10)

# check if something went wrong with maskcompare and assume error then
if [ -z "$DIFF_RATING" ]; then
    echo "$STARTTIME_COMPACT: 0:0.0:0:0.0:0:0.0:0:0.0:0.0:0.0 ERROR" >>"$DIR/differences"
    echo "stopping coastline processing due to maskcompare error ($DIFFERENCES)."
    exit 1
fi

#------------------------------------------------------------------------------

if [[ $DIFF_RATING > $DIFF_MAXIMUM ]]; then
    echo "$DIFFERENCES ERROR" | sed "s/short version/$STARTTIME_COMPACT/" >>"$DIR/differences"
    echo "stopping coastline processing due to difference test failing ($DIFF_RATING > $DIFF_MAXIMUM)."
    exit 1
fi

#------------------------------------------------------------------------------

echo "$DIFFERENCES OK" | sed "s/short version/$STARTTIME_COMPACT/" >>"$DIR/differences"
rm "$GOOD"
ln -s "mask-$STARTTIME_COMPACT.tiff" "$GOOD"

#------------------------------------------------------------------------------

# Remove old mask files. We do this here at the end, so we are sure not to
# delete any mask files still referenced by mask-good.tiff.
find "$DIR" -mtime +28 -type f -name 'mask-*.tiff' -delete


#------------------------------------------------------------------------------
