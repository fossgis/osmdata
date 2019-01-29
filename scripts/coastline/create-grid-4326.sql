-- ------------------------------------------
--
--   create-grid-4326.sql
--
-- ------------------------------------------

\t

\set ON_ERROR_STOP 'on'

\timing on

-- ------------------------------------------

SELECT 'creating 4326 grid...';

SELECT now() AS start_time \gset

DROP TABLE IF EXISTS grid_4326;

CREATE TABLE grid_4326 (
    id SERIAL PRIMARY KEY,
    x INTEGER,
    y INTEGER,
    geom GEOMETRY(POLYGON, 4326)
);

INSERT INTO grid_4326 (x, y, geom)
    SELECT x, y, ST_Intersection(
        ST_MakeEnvelope(-180, -90, 179.99999999, 89.99999999, 4326),
        ST_MakeEnvelope(
            x - (0.0005 / cos(radians(y + 0.5))),
            y - 0.0005,
            x + 1 + (0.0005 / cos(radians(y + 0.5))),
            y + 1 + 0.0005,
            4326))
    FROM generate_series(-180, 179) AS x,
         generate_series(-90, 89) AS y;

CREATE INDEX grid_4326_x_y_idx ON grid_4326 (x, y);

CREATE INDEX grid_4326_geom_idx ON grid_4326 USING GIST (geom);

SELECT 'created 4326 grid', date_trunc('second', now() - :'start_time')

-- ------------------------------------------
