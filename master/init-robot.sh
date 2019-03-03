#!/bin/bash

set -e
set -x

cd ~

MASTER=~/osmdata/master

# -- Compile tools --

git clone https://github.com/imagico/gdal-tools
cd gdal-tools
make gdal_maskcompare_wm
cd ~

git clone --branch 1.32.10 https://github.com/mapbox/tippecanoe
cd tippecanoe
make
cd ~

# -- Log --

mkdir -p ~/log

# -- hcloud setup --

hcloud context create osmdata

hcloud volume detach planet

$MASTER/create-host-keys.sh

# -- Web setup --

$MASTER/build-web.sh

# -- SSH setup --

ssh-keygen -t rsa -C robot -N '' -f ~/.ssh/id_rsa

cp $MASTER/users.yml.tmpl ~/users.yml

cat ~/.ssh/id_rsa.pub ~/.ssh/authorized_keys \
    | sed -e 's/^/        - /'  >>~/users.yml

