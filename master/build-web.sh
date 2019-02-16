#!/bin/sh

if [ "$USER" != "robot" ]; then
    echo "Must be run as user robot"
    exit 1
fi

jekyll build --source ~/osmdata/web --destination /srv/www/osmdata

