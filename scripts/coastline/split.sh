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

time ogr2ogr -f "PostgreSQL" PG:"dbname=${PGDATABASE} user=${PGUSER}" -overwrite -nln land_polygons_${srid} $DATADIR/coastlines-complete-${srid}.db land_polygons

time psql -f $BIN/create-grid-${srid}.sql

time psql -f $BIN/split-on-grid.sql --set=srid=${srid} --set=input_table=land_polygons_${srid} --set=input_field=wkb_geometry --set=output_table=land_polygons_grid_${srid}_union

time psql -f $BIN/split-${srid}.sql

if [ "$srid" = "3857" ]; then
    time psql -f $BIN/split-on-grid.sql --set=srid=3857 --set=input_table=simplified_land_polygons --set=input_field=geom --set=output_table=land_polygons_grid_3857_union
    time psql -f $BIN/split-3857-post.sql
fi

create_shape() {
    local dir=$DATADIR/results/$1
    local shape_layer=$2
    local in=$3
    local layer=$4

    mkdir -p $dir
    ogr2ogr -f "ESRI Shapefile" $dir -select geom -nln $shape_layer -overwrite "$in" $layer

    echo "UTF-8" >$dir/$2.cpg
}

create_shape_from_pg() {
    create_shape $1 $2 PG:"dbname=${PGDATABASE} user=${PGUSER}" $3
}

create_shape land-polygons-complete-${srid} land_polygons $DATADIR/coastlines-complete-${srid}.db land_polygons

create_shape_from_pg coastlines-split-${srid} lines coastlines_${srid}
create_shape_from_pg land-polygons-split-${srid} land_polygons land_polygons_grid_${srid}
create_shape_from_pg water-polygons-split-${srid} water_polygons water_polygons_grid_${srid}

if [ "$srid" = "3857" ]; then
    create_shape_from_pg simplified-land-polygons-split-${srid} simplified_land_polygons simplified_land_polygons
    create_shape_from_pg simplified-water-polygons-split-${srid} simplified_water_polygons simplified_water_polygons
fi

