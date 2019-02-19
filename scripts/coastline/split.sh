#!/bin/bash
#
#  split.sh SRID
#

set -x

set -e

DATADIR=/home/robot/data/coastline

srid=$1

#if [ -d $DATADIR/land-polygons-complete-${srid} ]; then
#    rm -fr $DATADIR/land-polygons-complete-${srid}
#fi
#
#time unzip $DATADIR/land-polygons-complete-${srid}.zip -d $DATADIR

psql -c "CREATE EXTENSION IF NOT EXISTS postgis;"

time ogr2ogr -f "PostgreSQL" PG:"dbname=${PGDATABASE} user=${PGUSER}" \
    -overwrite -lco GEOMETRY_NAME=geom -lco FID=id -nln land_polygons_${srid} \
    $DATADIR/coastlines-complete-${srid}.db land_polygons

if [ "$srid" = "3857" ] ; then
    xmin=-20037508.34
    ymin=-20037508.34
    xmax=20037508.34
    ymax=20037508.34
    overlap=50.0
    split=128
else
    xmin=-180
    ymin=-90
    xmax=180
    ymax=90
    overlap=0.0005
    split=360
fi

time psql --set=prefix=grid \
    --set=srid=$srid --set=split=$split --set=overlap=$overlap \
    --set=xmin=$xmin --set=xmax=$xmax --set=ymin=$ymin --set=ymax=$ymax \
    -f $BIN/create-grid.sql

time psql -f $BIN/split-on-grid.sql --set=srid=${srid} --set=input_table=land_polygons_${srid} --set=output_table=land_polygons_grid_${srid}_union

time psql -f $BIN/split-${srid}.sql

if [ "$srid" = "3857" ]; then
    time psql -f $BIN/split-on-grid.sql --set=srid=3857 --set=input_table=simplified_land_polygons --set=output_table=land_polygons_grid_3857_union
    time psql -f $BIN/split-3857-post.sql
fi

create_shape() {
    local dir=$DATADIR/results/$1
    local shape_layer=$2
    local in=$3
    local layer=$4

    mkdir -p $dir
    time ogr2ogr -f "ESRI Shapefile" $dir -nln $shape_layer -overwrite "$in" $layer

    echo "UTF-8" >$dir/$2.cpg
}

create_shape_from_pg() {
    create_shape $1 $2 PG:"dbname=${PGDATABASE} user=${PGUSER}" $3
}

create_shape land-polygons-complete-${srid} land_polygons $DATADIR/coastlines-complete-${srid}.db land_polygons
create_shape coastlines-split-${srid} lines $DATADIR/coastlines-split-${srid}.db lines

for t in land water; do
    psql -c "ALTER TABLE ${t}_polygons_grid_${srid} DROP COLUMN x, DROP COLUMN y;"
    create_shape_from_pg ${t}-polygons-split-${srid} ${t}_polygons ${t}_polygons_grid_${srid}
done

if [ "$srid" = "3857" ]; then
    create_shape_from_pg simplified-land-polygons-split-${srid} simplified_land_polygons simplified_land_polygons
    create_shape_from_pg simplified-water-polygons-split-${srid} simplified_water_polygons simplified_water_polygons
fi

