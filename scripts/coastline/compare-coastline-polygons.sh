#!/bin/bash
#------------------------------------------------------------------------------
#
#  compare_coastline_polygons DIR SOURCE
#
#  to reset remove symlink $DIR/mask-master.tiff
#
#------------------------------------------------------------------------------

set -e
set -x

DIFF_MAXIMUM=0.0000015

DIR="$1"
WEBDIR="/data/web/coastline"
SOURCE="$2"
STARTTIME_COMPACT=`date '+%Y%m%dT%H%M%S'`

test \! -z $DIR
test \! -z $SOURCE

rm -fr $DIR/land-polygons-split-3857

unzip $SOURCE -d $DIR

# limit growth of differences file
if [ -f $DIR/differences ]; then
    tail -100 $DIR/differences >$DIR/differences.new
    mv $DIR/differences.new $DIR/differences
fi

gdal_rasterize -q --config GDAL_CACHEMAX 1024 "$DIR/land-polygons-split-3857" -l land_polygons \
    -te -20037508.342789244 -20037508.342789244 20037508.342789244 20037508.342789244 \
    -init 0 -burn 255 -ts 8192 8192 -ot Byte -co COMPRESS=DEFLATE \
    $DIR/mask-$STARTTIME_COMPACT.tiff

rm -f $DIR/mask-current.tiff
ln -s $DIR/mask-$STARTTIME_COMPACT.tiff $DIR/mask-current.tiff

#------------------------------------------------------------------------------

# generate a "diff" image for human consumption
rm -f $DIR/mask-diff.tiff

if [ -e $DIR/mask-master.tiff ]; then
    gdal_calc.py -A $DIR/mask-master.tiff \
                 -B $DIR/mask-$STARTTIME_COMPACT.tiff \
                 --NoDataValue=0 --type=Byte --co=COMPRESS=DEFLATE \
                 --outfile=$DIR/mask-diff.tiff --calc="(A!=B)*255"
fi

#------------------------------------------------------------------------------

for img in current master diff; do
    mkdir -p $WEBDIR/$img
    gdal2tiles.py --webviewer none $DIR/mask-$img.tiff $WEBDIR/$img
done

#------------------------------------------------------------------------------

if [ ! -r "$DIR/mask-$STARTTIME_COMPACT.tiff" ]; then
    echo "$STARTTIME_COMPACT: 0:0.0:0:0.0:0:0.0:0:0.0:0.0:0.0 ERROR" >>$DIR/differences
    echo "stopping coastline processing due to raster mask generation error."
    exit 1
fi

#------------------------------------------------------------------------------

if [ ! -h $DIR/mask-master.tiff ]; then
    ln -s $DIR/mask-$STARTTIME_COMPACT.tiff $DIR/mask-master.tiff
    echo "$STARTTIME_COMPACT: 0:0.0:0:0.0:0:0.0:0:0.0:0.0:0.0 OK" >>$DIR/differences
    exit 0
fi

#------------------------------------------------------------------------------

DIFFERENCES=`gdal_maskcompare_wm $DIR/mask-master.tiff $DIR/mask-$STARTTIME_COMPACT.tiff 20000 | grep 'short version:'`
DIFF_RATING=`echo "$DIFFERENCES" | cut -d ':' -f 10`

# check if something went wrong with maskcompare and assume error then
if [ -z "$DIFF_RATING" ]; then
    echo "$STARTTIME_COMPACT: 0:0.0:0:0.0:0:0.0:0:0.0:0.0:0.0 ERROR" >>$DIR/differences
    echo "stopping coastline processing due to maskcompare error ($DIFFERENCES)."
    exit 1
fi

#------------------------------------------------------------------------------

if [[ $DIFF_RATING > $DIFF_MAXIMUM ]]; then
    echo "$DIFFERENCES ERROR" | sed "s/short version/$STARTTIME_COMPACT/" >>$DIR/differences
    echo "stopping coastline processing due to difference test failing ($DIFF_RATING > $DIFF_MAXIMUM)."
    exit 1
fi

#------------------------------------------------------------------------------

echo "$DIFFERENCES OK" | sed "s/short version/$STARTTIME_COMPACT/" >>$DIR/differences
rm $DIR/mask-master.tiff
ln -s mask-$STARTTIME_COMPACT.tiff $DIR/mask-master.tiff

#------------------------------------------------------------------------------

# Remove old mask files. We do this here at the end, so we are sure not to
# delete any mask files still referenced by mask-master.tiff.
find "$DIR" -mtime +28 -type f -name 'mask-*.tiff' -delete


#------------------------------------------------------------------------------
