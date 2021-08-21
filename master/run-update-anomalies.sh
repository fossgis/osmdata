#!/bin/bash
#
#  run-update-anomalies.sh
#

if [ "$USER" != "robot" ]; then
    echo "Must be run as user robot"
    exit 1
fi

echo "Running jobs: anomalies"

set -e

SERVER=update-anomalies

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

IP=$(hcloud server describe -o 'format={{.PublicNet.IPv4.IP}}' $SERVER)

echo $IP

sed -e "s/^IP /${IP} /" ~/ssh/known_hosts >~/.ssh/known_hosts

echo "Waiting for system to become ready..."
sleep 60
ssh -o ConnectTimeout=600 robot@${IP} cloud-init status --wait
echo "System initialized."

update_anomalies() {
    ssh robot@${IP} mkdir anomalies
    scp ~/osmdata/scripts/anomalies/* robot@${IP}:anomalies/
    scp ~/osm-data-anomaly-detection/build/src/odad-* robot@${IP}:anomalies/

    echo "Running anomalies job..."
    ssh robot@${IP} anomalies/update.sh
}

update_anomalies

RESULT=/data/anomalies
rm -fr $RESULT/new
mkdir -p $RESULT/new
scp robot@${IP}:/tmp/anomalies/\* $RESULT/new
ssh robot@${IP} sudo umount /mnt
sync

hcloud volume detach planet

hcloud server delete $SERVER

rm -fr $RESULT/old

if [ -f $RESULT/cur ]; then
    mv $RESULT/cur $RESULT/old
fi

mv $RESULT/new $RESULT/cur
sync

rm -fr $RESULT/old

if [ -f $RESULT/stats.db ]; then
    cp $RESULT/stats.db $RESULT/cur
fi

~/osmdata/scripts/anomalies/collect-stats.sh $RESULT/cur

mv $RESULT/cur/stats.db $RESULT/

~/osmdata/scripts/anomalies/stats-to-json.rb $RESULT/stats.db >$RESULT/stats.json.new
sync
mv $RESULT/stats.json.new $RESULT/stats.json

echo "run-update-anomalies done."

