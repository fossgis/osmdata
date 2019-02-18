-- ------------------------------------------
--
--   create-grid.sql
--
--   variables:
--      prefix: name prefix for grid table
--      srid: 4326, 3857 or other
--      split: number of splits
--      overlap: overlap (in map units)
--      xmin, ymin, xmax, ymax: bounds of the grid
--
-- ------------------------------------------

\t

\set ON_ERROR_STOP 'on'

\timing on

-- ------------------------------------------

SELECT 'creating ' || :srid || ' grid...';

SELECT now() AS start_time \gset

SELECT :'prefix' || '_' || :srid AS grid_table \gset
SELECT :'prefix' || '_' || :srid || '_x_y_idx' AS grid_table_x_y_idx \gset
SELECT :'prefix' || '_' || :srid || '_geom_idx' AS grid_table_geom_idx \gset

DROP TABLE IF EXISTS :grid_table;

CREATE TABLE :grid_table (
    id SERIAL PRIMARY KEY,
    x INTEGER,
    y INTEGER,
    geom GEOMETRY(POLYGON, :srid)
);

-- carthesian version
INSERT INTO :grid_table (x, y, geom)
    SELECT x, y, ST_Intersection(
        ST_MakeEnvelope(:xmin, :ymin, :xmax, :ymax, :srid),
        ST_MakeEnvelope(
            x * (:xmax - :xmin)/:split - :overlap,
            y * (:ymax - :ymin)/:split - :overlap,
            (x + 1) * (:xmax - :xmin)/:split + :overlap,
            (y + 1) * (:ymax - :ymin)/:split + :overlap,
            :srid))
    FROM generate_series(-:split/2, :split/2 - 1) AS x,
         generate_series(-:split/2, :split/2 - 1) AS y WHERE :srid <> 4326;

-- geographic version
INSERT INTO :grid_table (x, y, geom)
    SELECT x, y, ST_Intersection(
        ST_MakeEnvelope(:xmin, :ymin, :xmax, :ymax, :srid),
        ST_MakeEnvelope(
            x - (:overlap / cos(radians(y + 0.5))),
            y - :overlap,
            x + 1 + (:overlap / cos(radians(y + 0.5))),
            y + 1 + :overlap,
            :srid))
    FROM generate_series(-:split/2, :split/2 - 1) AS x,
         generate_series(-:split/4, :split/4 - 1) AS y WHERE :srid = 4326;

CREATE INDEX :grid_table_x_y_idx ON :grid_table (x, y);

CREATE INDEX :grid_table_geom_idx ON :grid_table USING GIST (geom);

SELECT 'created ' || :srid || ' grid', date_trunc('second', now() - :'start_time');

-- ------------------------------------------
