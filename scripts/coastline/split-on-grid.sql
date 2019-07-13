-- ------------------------------------------
--
--   split-on-grid.sql
--
--   variables:
--      srid: 4326 or 3857
--      input_table: table with input data to be split
--      output_table: name of output table
--
-- ------------------------------------------

\t

\set ON_ERROR_STOP 'on'

\timing on

SELECT now() AS start_time \gset

SELECT 'grid_' || :srid AS grid_table \gset

-- ------------------------------------------

SELECT :srid, 'splitting grid...';

SELECT now() AS last_time \gset

DROP TABLE IF EXISTS polygons_sub;

CREATE TABLE polygons_sub (
    id SERIAL PRIMARY KEY,
    geom GEOMETRY(MULTIPOLYGON, :srid)
);

ALTER TABLE polygons_sub ALTER COLUMN geom SET STORAGE EXTERNAL;

INSERT INTO polygons_sub (geom)
    SELECT ST_Multi(ST_Subdivide(geom, 1000))
        FROM :input_table;

CREATE INDEX polygons_sub_geom_idx ON polygons_sub USING GIST (geom);

SELECT 'subdivide polygons', date_trunc('second', now() - :'last_time'), date_trunc('second', now() - :'start_time');

-- ------------------------------------------

SELECT now() AS last_time \gset

DROP TABLE IF EXISTS polygons_grid_tmp;

CREATE TABLE polygons_grid_tmp (
    id SERIAL PRIMARY KEY,
    x INTEGER,
    y INTEGER,
    geom GEOMETRY(MULTIPOLYGON, :srid)
);

ALTER TABLE polygons_grid_tmp ALTER COLUMN geom SET STORAGE EXTERNAL;

INSERT INTO polygons_grid_tmp (x, y, geom)
    SELECT g.x, g.y, ST_CollectionExtract(ST_Multi(ST_Intersection(p.geom, g.geom)), 3)
        FROM polygons_sub p, :grid_table g
            WHERE p.geom && g.geom;

-- Remove the empty multipolygons created by the ST_CollectionExtract() above
DELETE FROM polygons_grid_tmp WHERE ST_NumGeometries(geom) = 0;

SELECT 'intersect polygons with grid', date_trunc('second', now() - :'last_time'), date_trunc('second', now() - :'start_time');

-- ------------------------------------------

SELECT now() AS last_time \gset

DROP TABLE IF EXISTS polygons_grid_union;

CREATE TABLE polygons_grid_union (
    id SERIAL PRIMARY KEY,
    x INTEGER,
    y INTEGER,
    geom GEOMETRY(MULTIPOLYGON, :srid)
);

ALTER TABLE polygons_grid_union ALTER COLUMN geom SET STORAGE EXTERNAL;

INSERT INTO polygons_grid_union (x, y, geom)
    SELECT x, y, ST_Multi(ST_Union(geom))
        FROM polygons_grid_tmp
            GROUP BY x, y;

CREATE INDEX polygons_grid_union_geom_idx ON polygons_grid_union USING GIST (geom);

SELECT 'union polygons', date_trunc('second', now() - :'last_time'), date_trunc('second', now() - :'start_time');

-- ------------------------------------------

SELECT now() AS last_time \gset

DROP TABLE polygons_grid_tmp;
DROP TABLE polygons_sub;

DROP TABLE IF EXISTS :output_table;
ALTER TABLE polygons_grid_union RENAME TO :output_table;

SELECT 'cleanup', date_trunc('second', now() - :'last_time'), date_trunc('second', now() - :'start_time');

-- ------------------------------------------

