
# Setup of Master Server

The files in this directory are used to set up the master server. You will
need an [Hetzner cloud](https://www.hetzner.com/cloud) account and the
[hcloud command line tool](https://github.com/hetznercloud/cli).

Here are the steps needed to install the master server:

* Go to the [Hetzner Cloud console](https://console.hetzner.cloud/) and log
  in.
* Add a new project.
* Add your ssh public key.
* Add a new API token to the project. Put the API token somewhere safe.
* Create a hcloud context: `hcloud context create osmdata`. It will ask you
  for the token you have just created.
* Create a new server. Instead of `$SSH_KEY` use the name of your ssh key
  you have just set up.

```
hcloud server create \
    --name osmdata \
    --location nbg1 \
    --type cx11 \
    --image debian-9 \
    --ssh-key $SSH_KEY
```

This uses the cheapest cloud server they have which costs 2,96 EUR per month.

* Create a new volume:

```
hcloud volume create \
    --name planet \
    --size 120 \
    --server osmdata \
    --format ext4 \
    --automount
```

* You should now be able to log into the server as root (`hcloud server ssh osmdata`)
  and see a volume mounted somewhere under `/mnt`.
* Copy the script `init.sh` to the new server and run it as `root` user. The
  script will ask for the Hetzner cloud token at some point which you have
  to enter.

You now have a script `/usr/local/bin/run-update.sh` which can be run as
`robot` user to do an update run.


# Notes

* The init script installs the `acmetool` software for setting up LetsEncrypt
  certificates, but doesn't actually use it. You have to do the TLS setup
  manually if you want it.


