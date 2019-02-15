#!/bin/sh

set -e
set -x

cd /home/robot

MASTER=/home/robot/osmdata/master

# -- Compile tools --

git clone https://github.com/imagico/gdal-tools
cd gdal-tools
make gdal_maskcompare_wm
cd /home/robot

# -- Log --

mkdir -p /home/robot/log

# -- hcloud setup --

hcloud context create osmdata

hcloud volume detach planet

$MASTER/create-host-keys.sh

# -- Web setup --

$MASTER/build-web.sh

# -- SSH setup --

ssh-keygen -t rsa -C robot -N '' -f /home/robot/.ssh/id_rsa

cp $MASTER/users.yml.tmpl ~/users.yml

cat .ssh/id_rsa.pub .ssh/authorized_keys \
    | sed -e 's/^/        - /'  >>~/users.yml

