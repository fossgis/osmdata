#!/bin/bash
#
#  servers2web.sh
#

set -euo pipefail

exec >/srv/www/osmdata/internal/servers

date '+%Y-%m-%dT%H:%M:%S'

hcloud server list

