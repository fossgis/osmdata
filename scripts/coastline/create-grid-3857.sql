-- ------------------------------------------
--
--   create-grid-3857.sql
--
-- ------------------------------------------

\t

\set ON_ERROR_STOP 'on'

\timing on

-- ------------------------------------------

SELECT 'creating 3857 grid...';

SELECT now() AS start_time \gset

DROP TABLE IF EXISTS grid_3857;

CREATE TABLE grid_3857 (
    id SERIAL PRIMARY KEY,
    x INTEGER,
    y INTEGER,
    geom GEOMETRY(POLYGON, 3857)
);

INSERT INTO grid_3857 (x, y, geom)
    SELECT x, y, ST_Intersection(
        ST_MakeEnvelope(-20037508.34, -20037508.34, 20037508.34, 20037508.34, 3857),
        ST_MakeEnvelope(
            x * 2*20037508.34/64 - 50.0,
            y * 2*20037508.34/64 - 50.0,
            (x + 1) * 2*20037508.34/64 + 50.0,
            (y + 1) * 2*20037508.34/64 + 50.0,
            3857))
    FROM generate_series(-32, 31) AS x,
         generate_series(-32, 31) AS y;

CREATE INDEX grid_3857_x_y_idx ON grid_3857 (x, y);

CREATE INDEX grid_3857_geom_idx ON grid_3857 USING GIST (geom);

SELECT 'created 3857 grid', date_trunc('second', now() - :'start_time');

-- ------------------------------------------
