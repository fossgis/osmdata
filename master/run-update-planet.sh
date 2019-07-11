#!/bin/bash
#
#  run-update-planet.sh
#

if [ "$USER" != "robot" ]; then
    echo "Must be run as user robot"
    exit 1
fi

set -e

SERVER=update-planet

# cx41: 4 CPUs, 16 GB RAM, 160 GB disk
STYPE=cx41

hcloud server create \
    --name $SERVER \
    --location nbg1 \
    --type $STYPE \
    --image debian-10 \
    --ssh-key admin \
    --user-data-from-file ~/osmdata/servers/$SERVER.yml \
    --user-data-from-file ~/users.yml \
    --user-data-from-file ~/ssh/keys.yml \
    --volume planet

IP=`hcloud server describe -o 'format={{.PublicNet.IPv4.IP}}' $SERVER`

echo $IP

sed -e "s/^IP /${IP} /" ~/ssh/known_hosts >~/.ssh/known_hosts

# The new server takes a while to be initialized even after the hcloud
# command returns. So to make sure we have a system we can ssh to, we wait
# a bit here.
sleep 180

ssh robot@${IP} mkdir planet
scp osmdata/scripts/planet/* robot@${IP}:planet/

ssh robot@${IP} planet/update.sh
ssh robot@${IP} sudo umount /mnt

hcloud volume detach planet

hcloud server delete $SERVER

echo "run-update-planet done."

