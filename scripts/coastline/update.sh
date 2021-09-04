#!/bin/bash
#------------------------------------------------------------------------------
#
#  coastline/update.sh
#
#------------------------------------------------------------------------------

set -euo pipefail
set -x

DATADIR=/home/robot/data/coastline
PLANETDIR=/mnt/data/planet

iso_date='+%Y-%m-%dT%H:%M:%S'

export BIN
BIN=$(cd "$(dirname "$0")" ; pwd -P)

PLANET=${PLANETDIR}/planet.osm.pbf
COASTLINES=${PLANETDIR}/coastlines.osm.pbf
DBFILE=$DATADIR/coastlines-debug.db

#------------------------------------------------------------------------------

echo "Started update-coastline"
date $iso_date

mkdir -p $DATADIR
rm -fr $DATADIR/*

#------------------------------------------------------------------------------
#
#  Extract coastline data
#
#------------------------------------------------------------------------------

#OUTPUT_RINGS="--output-rings"
OUTPUT_RINGS=""

rm -f $DATADIR/segments.dat $DBFILE.new

set +e
osmcoastline --verbose --overwrite --no-index \
             $OUTPUT_RINGS \
             -o $DBFILE.new \
             --write-segments=$DATADIR/segments.dat \
             --max-points=0 --bbox-overlap=0 \
             $COASTLINES

EXIT_CODE=$?
set -e
echo "osmcoastline exit code: $EXIT_CODE"

echo $EXIT_CODE >$DATADIR/osmcoastline_exit_code

if (( EXIT_CODE > 2 )); then
    exit 1
fi

mv $DBFILE.new $DBFILE

date $iso_date


#------------------------------------------------------------------------------
#
#  Update files needed for error checking
#
#------------------------------------------------------------------------------

OSMIDIR=$DATADIR/osmi

rm -fr $OSMIDIR
mkdir -p $OSMIDIR

ogr2ogr -f "ESRI Shapefile" $OSMIDIR/error_points.shp $DBFILE error_points
ogr2ogr -f "ESRI Shapefile" $OSMIDIR/error_lines.shp $DBFILE error_lines

rm -f $DATADIR/coastline-ways.db

osmcoastline_ways $COASTLINES $DATADIR/coastline-ways.db

ogr2ogr -f "ESRI Shapefile" -select name $OSMIDIR/ways.shp $DATADIR/coastline-ways.db ways

sqlite3 $DBFILE 'SELECT timestamp FROM meta;' | cut -d: -f1-2 >$OSMIDIR/tstamp

tar cCjf $DATADIR $DATADIR/osmi.tar.bz2 osmi

POINT_LAYERS="single_point_in_ring not_a_ring end_point fixed_end_point double_node tagged_node"
LINE_LAYERS="direction not_a_ring not_closed overlap added_line questionable invalid"

for layer in $POINT_LAYERS; do
    ogr2ogr -f "GeoJSON" "/vsigzip//$OSMIDIR/coastline_error_points_$layer.json.gz" \
        -select osm_id -where "error='$layer'" "$OSMIDIR/error_points.shp"
done

for layer in $LINE_LAYERS; do
    ogr2ogr -f "GeoJSON" "/vsigzip//$OSMIDIR/coastline_error_lines_$layer.json.gz" \
        -select osm_id -where "error='$layer'" "$OSMIDIR/error_lines.shp"
done

time ogr2ogr -f "GeoJSON" "/vsigzip//$OSMIDIR/coastline_ways.json.gz" "$OSMIDIR/ways.shp"

date $iso_date


#------------------------------------------------------------------------------
#
#  Create 3857 version of output
#
#------------------------------------------------------------------------------

run_osmcoastline_lines() {
    local srid=$1
    local file=coastlines-split-$srid

    rm -f "$DATADIR/$file.db.new"

    osmcoastline --verbose --overwrite --no-index \
                 --output-lines --output-polygons=none \
                 -o "$DATADIR/$file.db.new" \
                 "--srs=$srid" --max-points=1000 --bbox-overlap=0 \
                 "$COASTLINES" \
                 && true

    mv "$DATADIR/$file.db.new" "$DATADIR/$file.db"
}

run_osmcoastline_polygons() {
    local srid=$1
    local file=coastlines-complete-$srid

    rm -f "$DATADIR/$file.db.new"

    osmcoastline --verbose --overwrite --no-index \
                 -o "$DATADIR/$file.db.new" \
                 "--srs=$srid" --max-points=0 --bbox-overlap=0 \
                 "$COASTLINES" \
                 && true

    mv "$DATADIR/$file.db.new" "$DATADIR/$file.db"
}

run_osmcoastline_lines 4326
run_osmcoastline_polygons 4326

run_osmcoastline_lines 3857
run_osmcoastline_polygons 3857

### This takes longer than recreating 3857 coastlines from source
#rm -f $DATADIR/coastlines-complete-3857.db
#time ogr2ogr --config OGR_ENABLE_PARTIAL_REPROJECTION YES \
#             --config OGR_SQLITE_SYNCHRONOUS OFF \
#             -dsco SPATIALITE=yes \
#             -dsco INIT_WITH_EPSG=no \
#             -f "SQLite" \
#             -gt 65535 \
#             -s_srs "EPSG:4326" \
#             -t_srs "EPSG:3857" \
#             -skipfailures \
#             -clipdst -20037508.342789244 -20037508.342789244 20037508.342789244 20037508.342789244 \
#             $DATADIR/coastlines-complete-3857.db \
#             $DBFILE land_polygons lines

date $iso_date


#------------------------------------------------------------------------------
#
#  Generate split and simplified versions
#
#------------------------------------------------------------------------------

pg_run_split() {
    local srid=$1

    pg_virtualenv -o shared_buffers=2GB \
                  -o work_mem=512MB \
                  -o maintenance_work_mem=100MB \
                  -o checkpoint_timeout=15min \
                  -o checkpoint_completion_target=0.9 \
                  -o max_wal_size=2GB \
                  -o min_wal_size=80MB \
                  -o fsync=off \
                  -o synchronous_commit=off \
                  "$BIN/split.sh" \
                  "$srid"
}

pg_run_split 4326

date $iso_date

pg_run_split 3857

date $iso_date


#------------------------------------------------------------------------------
#
#  Finalize zip files with shapes
#
#------------------------------------------------------------------------------

# Parse extent from line like this:
#   Extent: (-180.000000, -78.732901) - (180.000000, 83.666473)
# into this:
#   -180.000000 -78.732901 180.000000 83.666473
parse_extent() {
    sed -e 's/^.*(\([0-9.-]\+\), \([0-9.-]\+\)) - (\([0-9.-]\+\), \([0-9.-]\+\))/\1 \2 \3 \4/'
}

mkshape() {
    local proj=$1
    local name=$2
    local shapedir=$DATADIR/results/$name
    local layer=$3

    echo "mkshape $proj $shapedir $layer"

    local INFO EXTENT GMTYPE FCOUNT

    INFO=$(ogrinfo -so "$shapedir/$layer.shp" "$layer")

    EXTENT=$(grep <<< "$INFO" '^Extent: ')
    GMTYPE=$(grep <<< "$INFO" '^Geometry: '      | cut -d ':' -f 2- | tr -d ' ')
    FCOUNT=$(grep <<< "$INFO" '^Feature Count: ' | cut -d ':' -f 2- | tr -d ' ')

    local XMIN YMIN XMAX YMAX
    read -r XMIN YMIN XMAX YMAX <<<"$(parse_extent <<<"$EXTENT")"

    if [ "$proj" = "3857" ]; then

        # this tests if the data extends beyond the 180 degree meridian
        # and adds '+over' to the projection definition in that case
        if [[ $XMIN < -20037509 ]]; then
            sed -i -e 's/+no_defs"/+no_defs +over"/' "$shapedir/$layer.prj"
        fi

        local LON_MIN LON_MAX LAT_MIN LAT_MAX bbox

        read LON_MIN LAT_MIN <<<$(gdaltransform -s_srs 'EPSG:3857' -t_srs 'EPSG:4326' -output_xy <<< "$XMIN $YMIN")
        read LON_MAX LAT_MAX <<<$(gdaltransform -s_srs 'EPSG:3857' -t_srs 'EPSG:4326' -output_xy <<< "$XMAX $YMAX")

        XMIN=$(echo "($XMIN+0.5)/1" | bc)
        XMAX=$(echo "($XMAX+0.5)/1" | bc)
        YMIN=$(echo "($YMIN+0.5)/1" | bc)
        YMAX=$(echo "($YMAX+0.5)/1" | bc)

        bbox=$(printf '(%.3f, %.3f) - (%.3f, %.3f)' "$LON_MIN" "$LAT_MIN" "$LON_MAX" "$LAT_MAX")
        local LAYERS="\n\n$layer.shp:\n\n  $FCOUNT $GMTYPE features\n  Mercator projection (EPSG: 3857)\n  Extent: ($XMIN, $YMIN) - ($XMAX, $YMAX)\n  In geographic coordinates: $bbox"
    else
        local bbox
        bbox=$(printf '(%.3f, %.3f) - (%.3f, %.3f)' $XMIN $YMIN $XMAX $YMAX)
        local LAYERS="\n\n$layer.shp:\n\n  $FCOUNT $GMTYPE features\n  WGS84 geographic coordinates (EPSG: 4326)\n  Extent: $bbox"
    fi

    local YEAR DATE CONTENT URL
    YEAR=$(date '+%Y')
    DATE=$(osmium fileinfo -g header.option.osmosis_replication_timestamp $PLANET)

    local url_prefix='https://osmdata.openstreetmap.de/data'

    if [ "$layer" = 'land_polygons' ]; then
        if [[ $name = *split* ]]; then
            CONTENT='land polygons, split into a grid with slight overlap'
        else
            CONTENT='land polygons'
        fi
        URL='land-polygons'
    elif [ "$layer" = 'simplified_land_polygons' ]; then
        CONTENT='coastline land polygons, simplified for rendering at low zooms'
        URL='land-polygons'
    elif [ "$layer" = 'simplified_water_polygons' ]; then
        CONTENT='coastline water polygons, simplified for rendering at low zooms and split into a grid'
        URL='water-polygons'
    elif [ "$layer" = 'water_polygons' ]; then
        CONTENT='coastline water polygons, split into a grid with slight overlap'
        URL='water-polygons'
    else
        CONTENT='coastlines'
        URL='coastlines'
    fi

    sed -e "s?@YEAR@?${YEAR}?g;s?@URL@?${url_prefix}/${URL}.html?g;s?@DATE@?${DATE}?g;s?@CONTENT@?${CONTENT}?g" "$BIN/README.tmpl" \
        | sed "/@LAYERS@/N;s?@LAYERS@?$LAYERS?" >"$shapedir/README.txt"

    rm -f "$shapedir.zip.new"
    (cd $DATADIR/results; zip --quiet "$name.zip.new" "$name"/*)
    mv "$shapedir.zip.new" "$shapedir.zip"
}

#------------------------------------------------------------------------------

mkshape 4326 coastlines-split-4326                lines
mkshape 3857 coastlines-split-3857                lines

mkshape 4326 land-polygons-complete-4326          land_polygons
mkshape 3857 land-polygons-complete-3857          land_polygons

mkshape 4326 land-polygons-split-4326             land_polygons
mkshape 3857 land-polygons-split-3857             land_polygons

mkshape 4326 water-polygons-split-4326            water_polygons
mkshape 3857 water-polygons-split-3857            water_polygons

mkshape 3857 simplified-land-polygons-complete-3857 simplified_land_polygons
mkshape 3857 simplified-water-polygons-split-3857   simplified_water_polygons

date $iso_date

#------------------------------------------------------------------------------

df -h

echo "Done."
date $iso_date

