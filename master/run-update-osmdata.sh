#!/bin/bash
#
#  run-update-osmdata.sh [JOBS...]
#
#  run-update-osmdata.sh                    -- Run all jobs
#  run-update-osmdata.sh coastline          -- Run only coastline job
#  run-update-osmdata.sh coastline icesheet -- Run coastline and icesheet jobs
#

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

sed -e "s/^IP /${IP} /" ~/ssh/known_hosts >~/.ssh/known_hosts

# The new server takes a while to be initialized even after the hcloud
# command returns. So to make sure we have a system we can ssh to, we wait
# a bit here.
sleep 180

# Some packages are installed from Debian backports, because we need the
# newer versions. This is done here instead of through the cloud-init setup
# in ~/osmdata/servers/$SERVER.yml, because we can't tell cloud-init to use
# the packages from backports.
ssh robot@${IP} sudo apt-get -y -t stretch-backports install \
    osmcoastline osmium-tool python3-pyosmium

# temporary fix until we have a newer package
scp ~/osmdata/scripts/coastline/osmcoastline robot@${IP}:
ssh robot@${IP} sudo cp osmcoastline /usr/bin/

update_job() {
    local job=$1

    ssh robot@${IP} mkdir $job
    scp ~/osmdata/scripts/$job/* robot@${IP}:$job/

    echo "Running $job job..."
    ssh robot@${IP} $job/update.sh

    echo "Copying results of $job job to master..."
    scp robot@${IP}:data/$job/results/\*.zip /data/new/
}

if [ "${jobs[coastline]}" = "1" ]; then
    update_job coastline
    scp robot@${IP}:data/coastline/osmi.tar.bz2 /data/osmi/
    scp robot@${IP}:data/coastline/osmi/\*.json.gz /data/err/
fi

if [ "${jobs[icesheet]}" = "1" ]; then
    update_job icesheet
fi

scp robot@${IP}:/mnt/data/planet/last-update /data/new/
ssh robot@${IP} sudo umount /mnt

hcloud volume detach planet

hcloud server delete $SERVER

echo "run-update-osmdata done."

