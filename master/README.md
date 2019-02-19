
# Setup of Master Server

The files in this directory are used to set up the master server. You will
need an [Hetzner cloud](https://www.hetzner.com/cloud) account and the
[hcloud command line tool](https://github.com/hetznercloud/cli).

Here are the steps needed to install the master server:

* Go to the [Hetzner Cloud console](https://console.hetzner.cloud/) and log
  in.
* Add a new project.
* Add one or more of your ssh public keys.
* Add a new API token to the project. Put the API token somewhere safe.
* Create a hcloud context: `hcloud context create osmdata`. It will ask you
  for the token you have just created.
* Create a new server. Instead of `$SSH_KEY` use the name of your ssh key
  you have just set up. (You can also use the `--ssh-key` option multiple
  times to add several keys.)

```
hcloud server create \
    --name osmdata \
    --location nbg1 \
    --type cx11 \
    --image debian-9 \
    --ssh-key $SSH_KEY
```

This uses the cheapest cloud server they have which costs 2.96 EUR per month.

* Create a new volume:

```
hcloud volume create \
    --name planet \
    --size 120 \
    --server osmdata \
    --format ext4 \
    --automount
```

* You should now be able to log into the server as root (`hcloud server ssh
  osmdata`) and see a volume mounted somewhere under `/mnt`.
* Copy the script `init.sh` to the new server and run it as `root` user:

```
IP=`hcloud server describe -o 'format={{.PublicNet.IPv4.IP}}' osmdata`
echo $IP
scp osmdata/master/init.sh root@$IP:/tmp/
ssh -t root@$IP /tmp/init.sh
```

The script will ask for the Hetzner cloud token at some point which you have to
enter. The `-t` option on the `ssh` command is important, otherwise it can't
ask for the token.

* If his script runs through without errors, you are done with the update of
  the master server and you can now log in as the `robot` user:

```
hcloud server ssh -u robot osmdata
```

# Operation

You have a script `/usr/local/bin/run-update.sh` which can be run as
`robot` user to do an update run. The first time this is run, it will download
a complete planet and update it using the hourly replication files. Further
runs will update from the planet of the last run. This will also run the
data processing and put the results into `/data/new/`.

After testing this you might want to create a cronjob for it.


# Notes

* The init script installs the `acmetool` software for setting up LetsEncrypt
  certificates, but doesn't actually use it. You have to do the TLS setup
  manually if you want it.
* While testing you might want to run the update script in `tmux`, because
  it will run for a few hours. `tmux` is already installed on the system.

