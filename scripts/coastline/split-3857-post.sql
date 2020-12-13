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

DROP TABLE IF EXISTS simplified_water_polygons;

CREATE TABLE simplified_water_polygons (
    id SERIAL PRIMARY KEY,
    x INTEGER,
    y INTEGER,
    geom GEOMETRY(POLYGON, 3857)
);

ALTER TABLE simplified_water_polygons ALTER COLUMN geom SET STORAGE EXTERNAL;

INSERT INTO simplified_water_polygons (x, y, geom)
    SELECT g.x, g.y, ST_MakeValid((ST_Dump(ST_Difference(g.geom, p.geom))).geom)
        FROM grid_3857 g, land_polygons_grid_3857_union p
            WHERE g.x = p.x AND g.y = p.y;

-- Delete some tiny slivers along the antimeridian created as a side-effect of our code
DELETE FROM simplified_water_polygons
    WHERE ST_Contains(ST_MakeEnvelope(-20037508.342789244, -20037508.342789244, -20037499.0, 14230070.0, 3857), geom)
       OR ST_Contains(ST_MakeEnvelope( 20037499.0, -20037508.342789244, 20037508.342789244, 14230080.0, 3857), geom);

INSERT INTO simplified_water_polygons (x, y, geom)
    SELECT x, y, geom
        FROM grid_3857
            WHERE ARRAY[x, y] NOT IN (SELECT DISTINCT ARRAY[x, y] FROM land_polygons_grid_3857_union);

-- ALTER TABLE simplified_water_polygons DROP COLUMN x, DROP COLUMN y;

CREATE INDEX simplified_water_polygons_geom_idx ON simplified_water_polygons USING GIST (geom);

SELECT 'create simplified water polygons', date_trunc('second', now() - :'last_time'), date_trunc('second', now() - :'start_time');

-- ------------------------------------------
