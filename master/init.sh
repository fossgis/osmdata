#!/bin/sh
#
#  Initialize the master server.
#
#  Must be run once as user "root" on the master server when it is first
#  created.
#

set -e
set -x

REPOSITORY=/home/robot/osmdata
BIN=/usr/local/bin

# -- Install Debian packages --

echo "deb http://deb.debian.org/debian stretch-backports main" >/etc/apt/sources.list.d/backports.list

apt-get update -y

apt-get dist-upgrade -u -y

apt-get install -y \
    apache2 \
    bc \
    cimg-dev \
    g++ \
    gdal-bin \
    git \
    jekyll \
    jq \
    libgdal-dev \
    libproj-dev \
    make \
    rsync \
    spatialite-bin \
    sqlite3 \
    tmux \
    unzip \
    zip \
    zsh

apt-get -t stretch-backports install -y \
    acmetool \
    libosmium2-dev \
    osmium-tool \
    python3-pyosmium

apt-get clean


# -- Install hcloud cli command --

wget -O /tmp/hcloud.tar.gz https://github.com/hetznercloud/cli/releases/download/v1.12.0/hcloud-linux-amd64-v1.12.0.tar.gz
tar xCf /tmp /tmp/hcloud.tar.gz
cp /tmp/hcloud-linux-*/bin/hcloud $BIN


# -- Create robot user --

adduser --gecos "Robot User" --disabled-password robot
mkdir /home/robot/.ssh
cp /root/.ssh/authorized_keys /home/robot/.ssh
chown -R robot:robot /home/robot/.ssh
chmod 700 /home/robot/.ssh
chmod 600 /home/robot/.ssh/authorized_keys


# -- Prepare planet volume --

MNT=`find /mnt -mindepth 1 -maxdepth 1 -type d`
mkdir -p $MNT/data/planet
chown -R robot:robot $MNT/data
umount $MNT


# -- Directory setup --

mkdir -p /srv/www/osmdata
chown robot:robot /srv/www/osmdata

for dir in checked compare osmi results web; do
    mkdir -p /data/$dir
    chown robot:robot /data/$dir
done


# -- Get git repository --

(cd /home/robot; su -c "git clone https://github.com/joto/osmdata $REPOSITORY" robot)


# -- Run robot user setup --

su -c /home/robot/osmdata/master/init-robot.sh robot


# -- Install binaries ---

cp /home/robot/gdal-tools/gdal_maskcompare_wm $BIN

for script in build-web.sh run-update.sh; do
    cp /home/robot/osmdata/master/$script $BIN
done


# -- Apache setup --

cp $REPOSITORY/master/apache.conf /etc/apache2/sites-available/000-default.conf

systemctl restart apache2.service


