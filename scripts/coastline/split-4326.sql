-- ------------------------------------------
--
--   split-4326.sql
--
-- ------------------------------------------

\t

\set ON_ERROR_STOP 'on'

\timing on

SELECT now() AS start_time \gset

-- ------------------------------------------

SELECT now() AS last_time \gset

DROP TABLE IF EXISTS land_polygons_grid_4326;

CREATE TABLE land_polygons_grid_4326 (
    id SERIAL PRIMARY KEY,
    x INTEGER,
    y INTEGER,
    geom GEOMETRY(POLYGON, 4326)
);

ALTER TABLE land_polygons_grid_4326 ALTER COLUMN geom SET STORAGE EXTERNAL;

INSERT INTO land_polygons_grid_4326 (x, y, geom)
    SELECT x, y, ST_MakeValid((ST_Dump(geom)).geom)
        FROM land_polygons_grid_4326_union;

CREATE INDEX land_polygons_grid_4326_geom_idx ON land_polygons_grid_4326 USING GIST (geom);

SELECT 'final land polygons', date_trunc('second', now() - :'last_time'), date_trunc('second', now() - :'start_time');

-- ------------------------------------------

SELECT now() AS last_time \gset

DROP TABLE IF EXISTS water_polygons_grid_4326;

CREATE TABLE water_polygons_grid_4326 (
    id SERIAL PRIMARY KEY,
    x INTEGER,
    y INTEGER,
    geom GEOMETRY(POLYGON, 4326)
);

ALTER TABLE water_polygons_grid_4326 ALTER COLUMN geom SET STORAGE EXTERNAL;

INSERT INTO water_polygons_grid_4326 (x, y, geom)
    SELECT g.x, g.y, ST_MakeValid((ST_Dump(ST_Difference(g.geom, p.geom))).geom)
        FROM grid_4326 g, land_polygons_grid_4326_union p
            WHERE g.x = p.x AND g.y = p.y;

INSERT INTO water_polygons_grid_4326 (x, y, geom)
    SELECT x, y, geom
        FROM grid_4326
            WHERE ARRAY[x, y] NOT IN (SELECT DISTINCT ARRAY[x, y] FROM land_polygons_grid_4326);

CREATE INDEX water_polygons_grid_4326_geom_idx ON water_polygons_grid_4326 USING GIST (geom);

SELECT 'create water polygons', date_trunc('second', now() - :'last_time'), date_trunc('second', now() - :'start_time');

-- ------------------------------------------

DROP TABLE land_polygons_grid_4326_union;

-- ------------------------------------------
