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

if [[ $# -eq 0 ]]; then
    jobs['coastline']=1
    jobs['icesheet']=1
else
    for job in "$@"; do
        jobs[$job]=1
    done
fi

echo "Running jobs: ${!jobs[*]}"

SERVER=update-osmdata

# cx42: 8 CPUs, 16 GB RAM, 160 GB disk
STYPE=cx42

VOLID=$(hcloud volume describe -o json planet | jq .id)

printf "#cloud-config\nmounts:\n    - [ '/dev/disk/by-id/scsi-0HC_Volume_${VOLID}', '/mnt' ]\n" | \
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
ssh -o ConnectTimeout=600 "robot@$IP" cloud-init status --wait
echo "System initialized."

update_job() {
    local job=$1

    # shellcheck disable=SC2029
    ssh "robot@$IP" mkdir "$job"
    scp ~/osmdata/scripts/"$job"/* "robot@$IP:$job/"

    echo "Running $job job..."
    # shellcheck disable=SC2029
    ssh "robot@$IP" "$job/update.sh"

    echo "Copying results of $job job to master..."
    scp "robot@$IP:data/$job/results/*.zip" /data/new/
    sync
}

if [[ -v jobs[coastline] ]]; then
    update_job coastline
    scp -C "robot@$IP:data/coastline/osmi-coastlines.db" /data/osmi/
    scp "robot@$IP:data/coastline/osmi/*.json.gz" /data/err/
    sync
    mv /data/osmi/osmi-coastlines.db /data/web/coastline/
fi

if [[ -v jobs[icesheet] ]]; then
    update_job icesheet
fi

scp "robot@$IP:/mnt/data/planet/last-update" /data/new/
ssh "robot@$IP" sudo umount /mnt

hcloud volume detach planet || true

hcloud server delete $SERVER

echo "run-update-osmdata done."

