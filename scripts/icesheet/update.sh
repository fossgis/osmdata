#!/bin/bash
#
#  icesheet/update.sh
#

DATADIR=/home/robot/data/icesheet
PLANETDIR=/mnt/data/planet

iso_date='+%Y-%m-%dT%H:%M:%S'

export BIN="$( cd "$(dirname "$0")" ; pwd -P )"

set -e
set -x

mkdir -p $DATADIR

export PLANET=${PLANETDIR}/planet.osm.pbf
export ANT=${PLANETDIR}/antarctica.osm.pbf
export ANT_COASTLINES=${PLANETDIR}/antarctica-coastlines.osm.pbf

export ANT_NATURAL=${DATADIR}/antarctica-natural

DB=$DATADIR/icesheet.db

export STATS=$DATADIR/stats

echo "Started icesheet/update.sh"
date $iso_date

rm -f $DATADIR/antarctica_icesheet.db
rm -rf $DATADIR/antarctica-icesheet-*
rm -f $DATADIR/coastlines-split-3857.db

echo "Creating coastline..."

osmcoastline --verbose --overwrite \
             --output-polygons=both --output-lines \
             -o $DB.new \
             --srs=3857 --max-points=500 \
             $ANT_COASTLINES \
             && true

mv $DB.new $DB

date $iso_date

echo "Extracting polygons tagged with 'natural'..."

osmium tags-filter --verbose --overwrite --output=$ANT_NATURAL.osm.pbf \
                   --remove-tags $ANT \
                   a/natural!=bay,cliff,sinkhole,cave_entrance,crevasse,dune,desert,valley,volcano,coastline;

osmium export --verbose --config=$BIN/osmium-export-config.json \
              --geometry-types=polygon --overwrite --output=$ANT_NATURAL.geojson \
              $ANT_NATURAL.osm.pbf

sed -e 's/"natural":/"type":/g' $ANT_NATURAL.geojson >${ANT_NATURAL}-type.geojson

date $iso_date

echo "Adding non-icesheet data to db..."
ogr2ogr --config OGR_SQLITE_SYNCHRONOUS OFF -f "SQLite" -gt 65535 \
        -s_srs "EPSG:4326" -t_srs "EPSG:3857" \
        -skipfailures -explodecollections \
        -spat -180 -85.05113 180 -60 -update -append \
        -nln noice -nlt POLYGON \
        $DB ${ANT_NATURAL}-type.geojson


date $iso_date

pragmas="PRAGMA journal_mode = OFF; PRAGMA synchronous = OFF; PRAGMA temp_store = MEMORY; PRAGMA cache_size = 1000000;"

SPLIT_SIZE=200000
EDGE_TYPE_ATTRIBUTE=ice_edge
EDGE_TYPE_ICE_OCEAN=ice_ocean
EDGE_TYPE_ICE_LAND=ice_land
EDGE_TYPE_ICE_ICE=ice_ice
COASTLINE_LAYER=lines

echo "${pragmas}

CREATE TABLE ice ( OGC_FID INTEGER PRIMARY KEY AUTOINCREMENT );
SELECT AddGeometryColumn('ice', 'GEOMETRY', 3857, 'MULTIPOLYGON', 'XY');
SELECT CreateSpatialIndex('ice', 'GEOMETRY');

INSERT INTO ice (OGC_FID, GEOMETRY)
    SELECT land_polygons.OGC_FID, CastToMultiPolygon(land_polygons.GEOMETRY)
        FROM land_polygons;

REPLACE INTO ice (OGC_FID, GEOMETRY)
    SELECT ice.OGC_FID, CastToMultiPolygon(ST_Difference(ice.GEOMETRY, ST_Union(noice.GEOMETRY)))
        FROM ice JOIN noice
            ON (ST_Intersects(ice.GEOMETRY, noice.GEOMETRY) AND noice.OGC_FID IN
                (SELECT ROWID FROM SpatialIndex WHERE f_table_name = 'noice' AND search_frame = ice.GEOMETRY))
            GROUP BY ice.OGC_FID;

.elemgeo ice GEOMETRY ice_split id_new id_old;
DELETE FROM ice;

INSERT INTO ice (GEOMETRY)
    SELECT CastToMultiPolygon(ice_split.GEOMETRY)
        FROM ice_split
        WHERE ST_Area(GEOMETRY) > 0.1;

SELECT DiscardGeometryColumn('ice_split', 'GEOMETRY');
DROP TABLE ice_split;
VACUUM;

CREATE TABLE noice_outline ( OGC_FID INTEGER PRIMARY KEY AUTOINCREMENT, oid INTEGER, iteration INTEGER );
SELECT AddGeometryColumn('noice_outline', 'GEOMETRY', 3857, 'MULTILINESTRING', 'XY');
SELECT CreateSpatialIndex('noice_outline', 'GEOMETRY');

INSERT INTO noice_outline (OGC_FID, oid, iteration, GEOMETRY)
    SELECT noice.OGC_FID, noice.OGC_FID, 0, CastToMultiLineString(ST_Boundary(noice.GEOMETRY))
        FROM noice;

.elemgeo noice_outline GEOMETRY noice_outline_split id_new id_old;
DELETE FROM noice_outline;

INSERT INTO noice_outline (oid, iteration, GEOMETRY)
    SELECT noice_outline_split.oid, 0, CastToMultiLineString(noice_outline_split.GEOMETRY)
        FROM noice_outline_split
        WHERE ST_Length(noice_outline_split.GEOMETRY) <= $SPLIT_SIZE;

INSERT INTO noice_outline (oid, iteration, GEOMETRY)
    SELECT noice_outline_split.oid, 1, CastToMultiLineString(ST_Line_Substring(noice_outline_split.GEOMETRY, 0.0, 0.5))
        FROM noice_outline_split
        WHERE ST_Length(noice_outline_split.GEOMETRY) > $SPLIT_SIZE;

INSERT INTO noice_outline (oid, iteration, GEOMETRY)
    SELECT noice_outline_split.oid, 1, CastToMultiLineString(ST_Line_Substring(noice_outline_split.GEOMETRY, 0.5, 1.0))
        FROM noice_outline_split
        WHERE ST_Length(noice_outline_split.GEOMETRY) > $SPLIT_SIZE;

SELECT DiscardGeometryColumn('noice_outline_split', 'GEOMETRY');
DROP TABLE noice_outline_split;" | spatialite -batch -bail -echo "$DB"

date $iso_date
echo "Iterating outline splitting..."

CNT=1
XCNT=1
while [ $XCNT -gt 0 ] ; do
    echo "${pragmas}
INSERT INTO noice_outline (oid, iteration, GEOMETRY)
    SELECT noice_outline.oid, ($CNT + 1), CastToMultiLineString(ST_Line_Substring(noice_outline.GEOMETRY, 0.0, 0.5))
        FROM noice_outline
        WHERE ST_Length(noice_outline.GEOMETRY) > $SPLIT_SIZE AND noice_outline.iteration = $CNT;

INSERT INTO noice_outline (oid, iteration, GEOMETRY)
    SELECT noice_outline.oid, ($CNT + 1), CastToMultiLineString(ST_Line_Substring(noice_outline.GEOMETRY, 0.5, 1.0))
        FROM noice_outline
        WHERE ST_Length(noice_outline.GEOMETRY) > $SPLIT_SIZE AND noice_outline.iteration = $CNT;

SELECT COUNT(*)
    FROM noice_outline
    WHERE ST_Length(noice_outline.GEOMETRY) > $SPLIT_SIZE AND noice_outline.iteration = ($CNT + 1);" | spatialite -batch -bail -echo "$DB" | tail -n 1 > "$DATADIR/cnt.txt"

    XCNT=$(cat $DATADIR/cnt.txt | xargs)
    echo "--- iteration $CNT ($XCNT) ---"
    CNT=$((CNT + 1))
done

rm -f "$DATADIR/cnt.txt"

date $iso_date
echo "Running spatialite processing (second part)..."

echo "${pragmas}
DELETE FROM noice_outline WHERE ST_Length(noice_outline.GEOMETRY) > $SPLIT_SIZE;
VACUUM;

CREATE TABLE ice_outline ( OGC_FID INTEGER PRIMARY KEY AUTOINCREMENT, $EDGE_TYPE_ATTRIBUTE TEXT );
SELECT AddGeometryColumn('ice_outline', 'GEOMETRY', 3857, 'MULTILINESTRING', 'XY');
SELECT CreateSpatialIndex('ice_outline', 'GEOMETRY');

CREATE TABLE ice_outline2 ( OGC_FID INTEGER PRIMARY KEY AUTOINCREMENT, $EDGE_TYPE_ATTRIBUTE TEXT );
SELECT AddGeometryColumn('ice_outline2', 'GEOMETRY', 3857, 'MULTILINESTRING', 'XY');
SELECT CreateSpatialIndex('ice_outline2', 'GEOMETRY');

UPDATE water_polygons SET GEOMETRY = ST_Buffer(GEOMETRY,0.01);

REPLACE INTO noice_outline (OGC_FID, oid, GEOMETRY)
    SELECT noice_outline.OGC_FID, noice_outline.oid, CastToMultiLineString(ST_Difference(noice_outline.GEOMETRY, ST_Union(water_polygons.GEOMETRY)))
        FROM noice_outline JOIN water_polygons
            ON (ST_Intersects(noice_outline.GEOMETRY, water_polygons.GEOMETRY) AND water_polygons.OGC_FID IN
                (SELECT ROWID FROM SpatialIndex WHERE f_table_name = 'water_polygons' AND search_frame = noice_outline.GEOMETRY))
        GROUP BY noice_outline.OGC_FID;

SELECT 'step 1', datetime('now');

REPLACE INTO noice_outline (OGC_FID, oid, GEOMETRY)
    SELECT noice_outline.OGC_FID, noice_outline.oid, CastToMultiLineString(ST_Difference(noice_outline.GEOMETRY, ST_Union(noice.GEOMETRY)))
        FROM noice_outline JOIN noice
            ON (ST_Intersects(noice_outline.GEOMETRY, noice.GEOMETRY) AND noice.OGC_FID IN
                (SELECT ROWID FROM SpatialIndex WHERE f_table_name = 'noice' AND search_frame = noice_outline.GEOMETRY) AND noice.OGC_FID <> noice_outline.oid)
        GROUP BY noice_outline.OGC_FID;

DELETE FROM noice_outline WHERE ST_Length(GEOMETRY) < 0.01 OR GEOMETRY IS NULL;

DELETE FROM ice_outline;

INSERT INTO ice_outline (OGC_FID, $EDGE_TYPE_ATTRIBUTE, GEOMETRY)
    SELECT $COASTLINE_LAYER.OGC_FID, '$EDGE_TYPE_ICE_OCEAN', CastToMultiLineString($COASTLINE_LAYER.GEOMETRY)
        FROM $COASTLINE_LAYER;

SELECT 'step 2', datetime('now');

REPLACE INTO ice_outline (OGC_FID, $EDGE_TYPE_ATTRIBUTE, GEOMETRY)
    SELECT ice_outline.OGC_FID, '$EDGE_TYPE_ICE_OCEAN', CastToMultiLineString(ST_Difference(ice_outline.GEOMETRY, ST_Union(ST_Buffer(noice.GEOMETRY, 0.01))))
        FROM ice_outline JOIN noice
            ON (ST_Intersects(ice_outline.GEOMETRY, noice.GEOMETRY) AND noice.OGC_FID IN
                (SELECT ROWID FROM SpatialIndex WHERE f_table_name = 'noice' AND search_frame = ST_Buffer(ice_outline.GEOMETRY, 0.01)))
        GROUP BY ice_outline.OGC_FID;

INSERT INTO ice_outline ($EDGE_TYPE_ATTRIBUTE, GEOMETRY)
    SELECT '$EDGE_TYPE_ICE_LAND', noice_outline.GEOMETRY
        FROM noice_outline;

INSERT INTO ice_outline2 (OGC_FID, $EDGE_TYPE_ATTRIBUTE, GEOMETRY)
    SELECT OGC_FID, $EDGE_TYPE_ATTRIBUTE, GEOMETRY
        FROM ice_outline;

SELECT 'step 3', datetime('now');

REPLACE INTO ice_outline2 (OGC_FID, $EDGE_TYPE_ATTRIBUTE, GEOMETRY)
    SELECT ice_outline2.OGC_FID, '$EDGE_TYPE_ICE_LAND', CastToMultiLineString(ST_Difference(ice_outline2.GEOMETRY, ST_Union(ST_Buffer(noice.GEOMETRY, 0.01))))
        FROM ice_outline2 JOIN noice
            ON (ST_Intersects(ice_outline2.GEOMETRY, noice.GEOMETRY) AND noice.OGC_FID IN
                (SELECT ROWID FROM SpatialIndex WHERE f_table_name = 'noice' AND search_frame = ST_Buffer(ice_outline2.GEOMETRY, 0.01)) AND noice.type = 'glacier')
        GROUP BY ice_outline2.OGC_FID;

SELECT 'step 4', datetime('now');

INSERT INTO ice_outline2 ($EDGE_TYPE_ATTRIBUTE, GEOMETRY)
    SELECT '$EDGE_TYPE_ICE_ICE', CastToMultiLineString(ST_Intersection(ice_outline.GEOMETRY, ST_Union(ST_Buffer(noice.GEOMETRY, 0.01))))
        FROM ice_outline JOIN noice
            ON (ST_Intersects(ice_outline.GEOMETRY, noice.GEOMETRY) AND noice.OGC_FID IN
                (SELECT ROWID FROM SpatialIndex WHERE f_table_name = 'noice' AND search_frame = ST_Buffer(ice_outline.GEOMETRY, 0.01)) AND noice.type = 'glacier')
        GROUP BY ice_outline.OGC_FID;

DELETE FROM ice_outline;
SELECT DisableSpatialIndex('ice_outline', 'GEOMETRY');
DROP TABLE idx_ice_outline_GEOMETRY;

SELECT DiscardGeometryColumn('ice_outline', 'GEOMETRY');
SELECT RecoverGeometryColumn('ice_outline', 'GEOMETRY', 3857, 'LINESTRING', 'XY');
SELECT CreateSpatialIndex('ice_outline', 'GEOMETRY');

.elemgeo ice_outline2 GEOMETRY ice_outline2_flat id_new id_old;

INSERT INTO ice_outline ($EDGE_TYPE_ATTRIBUTE, GEOMETRY)
    SELECT ice_outline2_flat.$EDGE_TYPE_ATTRIBUTE, ice_outline2_flat.GEOMETRY
        FROM ice_outline2_flat
        WHERE ST_Length(GEOMETRY) > 0.01;

DELETE FROM ice_outline2;
SELECT DisableSpatialIndex('ice_outline2', 'GEOMETRY');
DROP TABLE idx_ice_outline2_GEOMETRY;
SELECT DiscardGeometryColumn('ice_outline2', 'GEOMETRY');
DROP TABLE ice_outline2;

SELECT DiscardGeometryColumn('ice_outline2_flat', 'GEOMETRY');
DROP TABLE ice_outline2_flat;
VACUUM;" | spatialite -batch -bail -echo "$DB"

rm -rf "$DATADIR/antarctica-icesheet-outlines-3857"
mkdir "$DATADIR/antarctica-icesheet-outlines-3857"
rm -rf "$DATADIR/antarctica-icesheet-polygons-3857"
mkdir "$DATADIR/antarctica-icesheet-polygons-3857"

date $iso_date
echo "Converting results to shapefiles..."

ogr2ogr -skipfailures -explodecollections \
    -spat -20037508.342789244 -20037508.342789244 20037508.342789244 -8300000 \
    -clipsrc spat_extent \
    $DATADIR/antarctica-icesheet-polygons-3857/icesheet_polygons.shp \
    -nln icesheet_polygons -nlt POLYGON \
    $DB ice

ogr2ogr -skipfailures -explodecollections \
    -spat -20037508.342789244 -20037508.342789244 20037508.342789244 -8300000 \
    -clipsrc spat_extent \
    $DATADIR/antarctica-icesheet-outlines-3857/icesheet_outlines.shp \
    -nln icesheet_outlines -nlt LINESTRING \
    $DB ice_outline

date $iso_date

echo "Calling update-icesheet-zip.sh..."

$BIN/update-icesheet-zip.sh

df -h

date $iso_date

echo "Done."

