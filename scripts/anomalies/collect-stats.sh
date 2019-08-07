#!/bin/sh
#
#  collect-stats.sh DIR
#

if [ -z "$1" ]; then
    echo "Usage: collect-stats.sh DIR"
    exit 2
fi

DIR=$1

echo 'CREATE TABLE IF NOT EXISTS stats (date TEXT, key TEXT, value INT64 DEFAULT 0);' \
    | sqlite3 -bail -batch $DIR/stats.db

echo 'CREATE TABLE IF NOT EXISTS new_stats (date TEXT, key TEXT, value INT64 DEFAULT 0);' \
    | sqlite3 -bail -batch $DIR/stats.db

for db in $DIR/stats-*.db; do
    echo "$db:"
    echo "INSERT INTO new_stats SELECT * FROM db.stats;" \
        | sqlite3 -bail -batch -echo -cmd "ATTACH DATABASE '$db' AS db;" $DIR/stats.db
done

echo "UPDATE new_stats SET date = (SELECT max(date) FROM new_stats);" \
    | sqlite3 -bail -batch -echo $DIR/stats.db
echo "INSERT INTO stats SELECT * FROM new_stats;" \
    | sqlite3 -bail -batch -echo $DIR/stats.db
echo "DROP TABLE new_stats;" \
    | sqlite3 -bail -batch -echo $DIR/stats.db

