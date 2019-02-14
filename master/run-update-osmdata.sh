#!/bin/bash
#
#  run-update-osmdata.sh
#

set -e

SERVER=update-osmdata

# cx31: 2 CPUs, 8 GB RAM, 80 GB disk
STYPE=cx31

hcloud server create \
    --name $SERVER \
    --location nbg1 \
    --type $STYPE \
    --image debian-9 \
    --ssh-key joto \
    --user-data-from-file ~/osmdata/servers/$SERVER.yml \
    --user-data-from-file ~/users.yml \
    --user-data-from-file ~/ssh/keys.yml \
    --volume planet

IP=`hcloud server describe -o 'format={{.PublicNet.IPv4.IP}}' $SERVER`

echo $IP

sed -e "s/^IP /${IP} /" ssh/known_hosts >~/.ssh/known_hosts

sleep 180

ssh robot@${IP} sudo apt-get -y -t stretch-backports install osmcoastline osmium-tool python3-pyosmium

# temp until we have package
scp ~/osmcoastline robot@${IP}:
ssh robot@${IP} sudo cp osmcoastline /usr/bin/

for job in coastline icesheet; do
    ssh robot@${IP} mkdir $job
    scp osmdata/scripts/$job/* robot@${IP}:$job/
    ssh robot@${IP} $job/update.sh
    scp robot@${IP}:data/$job/results/\*.zip /data/results/
done

scp robot@${IP}:data/coastline/osmi.tar.bz2 /data/osmi/
ssh robot@${IP} sudo umount /mnt

hcloud volume detach planet

hcloud server delete $SERVER

