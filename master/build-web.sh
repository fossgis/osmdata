#!/bin/bash

set -euo pipefail

if [ "$USER" != "robot" ]; then
    echo "Must be run as user robot"
    exit 1
fi

jekyll build --source ~/osmdata/web --destination /srv/www/osmdata

