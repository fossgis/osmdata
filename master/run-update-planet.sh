#!/bin/bash
#
#  run-update-planet.sh
#

set -euo pipefail

if [ "$USER" != "robot" ]; then
    echo "Must be run as user robot"
    exit 1
fi

SERVER=update-planet

# cx41: 8 CPUs, 16 GB RAM, 160 GB disk
STYPE=cx42

VOLID=$(hcloud volume describe -o json planet | jq .id)

printf "#cloud-config\nmounts:\n    - [ 'ID=scsi-0HC_Volume_${VOLID}', '/mnt' ]\n" | \
hcloud server create \
    --name $SERVER \
    --location nbg1 \
    --type $STYPE \
    --image debian-12 \
    --ssh-key admin \
    --user-data-from-file ~/osmdata/servers/$SERVER.yml \
    --user-data-from-file ~/users.yml \
    --user-data-from-file ~/ssh/keys.yml \
    --user-data-from-file - \
    --volume planet

IP=$(hcloud server ip $SERVER)

echo "$IP"

sed -e "s/^IP /${IP} /" ~/ssh/known_hosts >~/.ssh/known_hosts

echo "Waiting for system to become ready..."
sleep 60
ssh -o ConnectTimeout=600 "robot@${IP}" cloud-init status --wait
echo "System initialized."

ssh "robot@${IP}" mkdir planet
scp ~/osmdata/scripts/planet/* "robot@${IP}:planet/"

ssh "robot@${IP}" planet/update.sh
ssh "robot@${IP}" sudo umount /mnt

hcloud volume detach planet || true

hcloud server delete $SERVER

echo "run-update-planet done."

