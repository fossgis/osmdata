#!/bin/bash
#
#  run-update-osmdata.sh [JOBS...]
#
#  run-update-osmdata.sh                    -- Run all jobs
#  run-update-osmdata.sh coastline          -- Run only coastline job
#  run-update-osmdata.sh coastline icesheet -- Run coastline and icesheet jobs
#

set -euo pipefail

if [ "$USER" != "robot" ]; then
    echo "Must be run as user robot"
    exit 1
fi

declare -A jobs

if [ -z "$1" ]; then
    jobs['coastline']=1
    jobs['icesheet']=1
else
    for job in $*; do
        jobs[$job]=1
    done
fi

echo "Running jobs: ${!jobs[@]}"

SERVER=update-osmdata

# cx31: 2 CPUs, 8 GB RAM, 80 GB disk
STYPE=cx31

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

IP=$(hcloud server describe -o 'format={{.PublicNet.IPv4.IP}}' $SERVER)

echo "$IP"

sed -e "s/^IP /${IP} /" ~/ssh/known_hosts >~/.ssh/known_hosts

echo "Waiting for system to become ready..."
sleep 60
ssh -o ConnectTimeout=600 robot@${IP} cloud-init status --wait
echo "System initialized."

update_job() {
    local job=$1

    ssh "robot@${IP}" mkdir $job
    scp ~/osmdata/scripts/$job/* robot@${IP}:$job/

    echo "Running $job job..."
    ssh "robot@${IP}" $job/update.sh

    echo "Copying results of $job job to master..."
    scp robot@${IP}:data/$job/results/\*.zip /data/new/
    sync
}

if [ "${jobs[coastline]}" = "1" ]; then
    update_job coastline
    scp robot@${IP}:data/coastline/osmi.tar.bz2 /data/osmi/
    scp robot@${IP}:data/coastline/osmi/\*.json.gz /data/err/
    sync
    mv /data/osmi/osmi.tar.bz2 /data/web/coastline/
fi

if [ "${jobs[icesheet]}" = "1" ]; then
    update_job icesheet
fi

scp "robot@${IP}:/mnt/data/planet/last-update" /data/new/
ssh "robot@${IP}" sudo umount /mnt

hcloud volume detach planet

hcloud server delete $SERVER

echo "run-update-osmdata done."

