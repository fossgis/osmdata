
# OSMData

The [OpenStreetMap project](https://www.openstreetmap.org/) collects an amazing
amount of geodata and makes it available to the world for free. But the raw
OpenStreetMap data is hard to use. This repository contains scripts to set up
a server that processes some OSM data and brings it into a format for easier
use.

Currently these scripts can be used to derive

* Coastline data (in the form of linestrings or land or water polygons for the
  worlds land masses or oceans).
* Antarctic icesheet data.

datasets from OSM data.

The icesheet scripts are based on https://github.com/imagico/icesheet_proc.

## Public server

A server running this code and offering the results for download to the general
public is at https://osmdata.openstreetmap.de/ .

## Overview

The scripts are intended to work in the [Hetzner
Cloud](https://www.hetzner.com/cloud). But it should be possible to port
them to other cloud providers.

One server runs all the time as webserver and "master of ceremonies". It will
start other servers regularly to update a planet file and do the data
processing. The results are then copied back to the master server and are
available for download from there.

## Setting up a master server

See [the master README](master/README.md) on how to set up a master server.

## License

Unless otherwise mentioned everything in the repository is available under
the GNU GENERAL PUBLIC LICENSE Version 3. See the file COPYING for the
complete text of the license.

