#!/bin/sh
#
#  servers2web.sh
#

exec >/srv/www/osmdata/internal/servers

date '+%Y-%m-%dT%H:%M:%S'

hcloud server list

