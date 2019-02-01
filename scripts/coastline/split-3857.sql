-- ------------------------------------------
--
--   split-3857.sql
--
-- ------------------------------------------

\t

\set ON_ERROR_STOP 'on'

\timing on

SELECT now() AS start_time \gset

-- ------------------------------------------

SELECT now() AS last_time \gset

DROP TABLE IF EXISTS land_polygons_grid_3857;

CREATE TABLE land_polygons_grid_3857 (
    id SERIAL PRIMARY KEY,
    x INTEGER,
    y INTEGER,
    geom GEOMETRY(POLYGON, 3857)
);

ALTER TABLE land_polygons_grid_3857 ALTER COLUMN geom SET STORAGE EXTERNAL;

INSERT INTO land_polygons_grid_3857 (x, y, geom)
    SELECT x, y, ST_MakeValid((ST_Dump(geom)).geom)
        FROM land_polygons_grid_3857_union;

CREATE INDEX land_polygons_grid_3857_geom_idx ON land_polygons_grid_3857 USING GIST (geom);

SELECT 'final land polygons', date_trunc('second', now() - :'last_time'), date_trunc('second', now() - :'start_time');

-- ------------------------------------------

SELECT now() AS last_time \gset

DROP TABLE IF EXISTS water_polygons_grid_3857;

CREATE TABLE water_polygons_grid_3857 (
    id SERIAL PRIMARY KEY,
    x INTEGER,
    y INTEGER,
    geom GEOMETRY(POLYGON, 3857)
);

ALTER TABLE water_polygons_grid_3857 ALTER COLUMN geom SET STORAGE EXTERNAL;

INSERT INTO water_polygons_grid_3857 (x, y, geom)
    SELECT g.x, g.y, ST_MakeValid((ST_Dump(ST_Difference(g.geom, p.geom))).geom)
        FROM grid_3857 g, land_polygons_grid_3857_union p
            WHERE g.x = p.x AND g.y = p.y;

-- Delete some tiny slivers along the antimeridian created as a side-effect of our code
DELETE FROM water_polygons_grid_3857
    WHERE ST_Contains(ST_MakeEnvelope(-20037508.342789244, -20037508.342789244, -20037499.0, 14230070.0, 3857), geom)
       OR ST_Contains(ST_MakeEnvelope( 20037499.0, -20037508.342789244, 20037508.342789244, 14230080.0, 3857), geom);

INSERT INTO water_polygons_grid_3857 (x, y, geom)
    SELECT x, y, geom
        FROM grid_3857
            WHERE ARRAY[x, y] NOT IN (SELECT DISTINCT ARRAY[x, y] FROM land_polygons_grid_3857);

CREATE INDEX water_polygons_grid_3857_geom_idx ON water_polygons_grid_3857 USING GIST (geom);

SELECT 'create water polygons', date_trunc('second', now() - :'last_time'), date_trunc('second', now() - :'start_time');

-- ------------------------------------------

SELECT now() AS last_time \gset

DROP TABLE IF EXISTS simplified_land_polygons;

CREATE TABLE simplified_land_polygons (
    id SERIAL PRIMARY KEY,
    geom GEOMETRY(POLYGON, 3857)
);

ALTER TABLE simplified_land_polygons ALTER COLUMN geom SET STORAGE EXTERNAL;

INSERT INTO simplified_land_polygons (id, geom)
    SELECT id, ST_SimplifyPreserveTopology(geom, 300)
        FROM land_polygons_3857 WHERE ST_Area(geom) > 300000;

SELECT 'simplified land polygons', date_trunc('second', now() - :'last_time'), date_trunc('second', now() - :'start_time');

-- ------------------------------------------

DROP TABLE land_polygons_grid_3857_union;

-- ------------------------------------------
