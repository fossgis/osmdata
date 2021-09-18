#!/bin/bash
#
#  run-update-low-planet-from-planet.sh
#

set -euo pipefail

if [ "$USER" != "robot" ]; then
    echo "Must be run as user robot"
    exit 1
fi

SERVER=update-low-planet

# ccx41: 16 CPUs, 64 GB RAM, 360 GB disk
STYPE=ccx41

hcloud server create \
    --name $SERVER \
    --location nbg1 \
    --type $STYPE \
    --image debian-11 \
    --ssh-key admin \
    --user-data-from-file ~/osmdata/servers/$SERVER.yml \
    --user-data-from-file ~/users.yml \
    --user-data-from-file ~/ssh/keys.yml \
    --volume planet

IP=$(hcloud server ip $SERVER)

echo "$IP"

sed -e "s/^IP /${IP} /" ~/ssh/known_hosts >~/.ssh/known_hosts

echo "Waiting for system to become ready..."
sleep 60
ssh -o ConnectTimeout=600 "robot@${IP}" cloud-init status --wait
echo "System initialized."

ssh "robot@${IP}" mkdir low-planet
scp ~/osmdata/scripts/low-planet/* "robot@${IP}:low-planet/"

ssh "robot@${IP}" low-planet/update.sh
ssh "robot@${IP}" sudo umount /mnt

hcloud volume detach planet

hcloud server delete $SERVER

echo "run-update-planet done."

