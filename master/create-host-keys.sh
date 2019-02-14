#!/bin/sh
#
#  create-host-keys.sh
#

set -e
set -x

DIR=~/ssh

mkdir -p $DIR
rm -f $DIR/*

echo "#cloud-config\n\nssh_keys:" >$DIR/keys.yml

for type in rsa dsa ecdsa; do
    keyfile="$DIR/ssh_host_${type}_key"
    ssh-keygen -t $type -N '' -C cloud -f $keyfile >/dev/null

    (
    echo "  ${type}_private: |"
    sed -e 's/^/    /' $keyfile
    echo
    echo -n "  ${type}_public: "
    cat $keyfile.pub
    echo
    ) >>$DIR/keys.yml

    echo -n "IP " >>$DIR/known_hosts
    cat $keyfile.pub >>$DIR/known_hosts
done

