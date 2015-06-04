CernVM and Condor in a Docker container
=======================================

Ideas behind this project:

* running CernVM from CVMFS as a Docker container
* running one-job, one-core Condor (the "HT" is mute) Docker containers as
  execute nodes


## Running CernVM inside a Docker container

We provide the `docker-cernvm` utility that helps running a container with a
proper CernVM environment: the CernVM image will be obtained by CVMFS and does
not need to be entirely imported into Docker.

CernVM, as a virtual machine, works with the principle of *overlays*: the base
read-only filesystem is overlaid with a read-write copy. The CernVM virtual
machine currently uses AUFS as overlay mechanism.

Docker uses *layers* as well, superimposed using an overlay mechanism. In our
configuration, AUFS is used, which is the same used by CernVM.

This is a fortunate coincidence: we are going to "trick" Docker into thinking
that a CVMFS-mounted root directory of CernVM is one of its base images, and it
will perform automatically all the necessary overlays for us.


### Preface: configuring CernVM-FS on the host machine

CernVM-FS must be installed on your host machine. It is better if autofs is not
configured: we are going to mount things manually.

There is currently a single CernVM-FS repository for the "stable" CernVM:

* cernvm-prod.cern.ch

This is available from the various Stratum 1s preconfigured with the standard
CernVM-FS installation (keys included). You need to download the public keys
from [here](https://github.com/cernvm/cernvm-micro/tree/master/packages.d/cvmfs-config/etc/cvmfs/keys)
for the additional "experimental" repositories:

* cernvm-devel.cern.ch
* cernvm-sl7.cern.ch
* cernvm-slc4.cern.ch
* cernvm-slc5.cern.ch
* cernvm-testing.cern.ch

all of them available directly from the Stratum 0 **hepvm.cern.ch**. Keys must
be stored under `/etc/cvmfs/keys/cern.ch` of the machine hosting the containers.

Updated list with mapping available [here](https://github.com/cernvm/cernvm-micro/blob/master/branch2server). To download all of them:

```bash
cd /etc/cvmfs/keys/cern.ch/
for r in cernvm-devel.cern.ch cernvm-sl7.cern.ch cernvm-slc4.cern.ch cernvm-slc5.cern.ch cernvm-testing.cern.ch ; do
  rm -f ${r}.pub
  wget https://raw.githubusercontent.com/cernvm/cernvm-micro/master/packages.d/cvmfs-config/etc/cvmfs/keys/${r}/${r}.pub
done
```

Concerning the repository configuration files, only cernvm-prod.cern.ch is
preconfigured. To configure the others, create, for instance, the file:

```
/etc/cvmfs/config.d/cernvm-devel.cern.ch.local
```

with the following content:

```bash
CVMFS_SERVER_URL="http://hepvm.cern.ch/cvmfs/@fqrn@"
CVMFS_CLAIM_OWNERSHIP=no
#CVMFS_REPOSITORY_TAG=cernvm-system-3.3.0.5
```

Specifying the tag is optional: by default, the latest snapshot is selected.
Just symlink it to the other experimental repos:

```bash
cd /etc/cvmfs/config.d/
ln -nfs cernvm-devel.cern.ch.local cernvm-sl7.cern.ch.local
ln -nfs cernvm-devel.cern.ch.local cernvm-slc4.cern.ch.local
ln -nfs cernvm-devel.cern.ch.local cernvm-slc5.cern.ch.local
ln -nfs cernvm-devel.cern.ch.local cernvm-testing.cern.ch.local
```

It should be now possible to mount every experimental repository.


### Register the CernVM Docker image

Registering the CernVM Docker image is as simple as this:

```bash
docker-cernvm --tag dberzano/cernvm register
```

This outputs:

```
Registering CernVM dummy image to Docker as "dberzano/cernvm"...ok
Fetching Image ID for "dberzano/cernvm"...671f3f53b3
All operations executed successfully
```

Check with `docker images`:

```
docker images
REPOSITORY              TAG                 IMAGE ID            CREATED             VIRTUAL SIZE
dberzano/cernvm         latest              671f3f53b3bb        56 seconds ago      0 B
```

Note that this is not tied to any specific CernVM version. We will decide which
one to use at the **mount** stage.


### Mounting the root filesystem from CVMFS over the Docker image

This operation requires root privileges. Do:

```bash
sudo ./docker-cernvm --tag dberzano/cernvm --branch cernvm-devel.cern.ch mount
```

The `--branch` switch is optional: if not specified, `cernvm-prod.cern.ch` will
be used.

The `--tag` switch is mandatory: it specifies the repository (and, optionally,
the tag) to use. It uses the standard Docker format:

```
username/repository:tag
```

The `tag` part is optional and is mapped to `latest` if not specified.

Sample output:

```
Fetching Image ID for "dberzano/cernvm"...671f3f53b3
Getting layers for 671f3f53b3...ok
Creating mountpoint /mnt/static_cernvm_cernvm-devel.cern.ch...ok
Mounting main CernVM branch cernvm-devel.cern.ch...ok
Bind-mounting CernVM branch cernvm-devel.cern.ch over 6f7834ff04...ok
Layer 6f7834ff04 freshly mounted.
CernVM snapshot in use: cernvm-system-3.3.58.0
All operations executed successfully
```

Note that the mount operation automatically unmounts and remounts the CernVM
repository, if possible (*i.e.* if no Docker images using it are running).

> This opens the possibility, for instance, to automatically update to the
> latest CernVM snapshot, since for the moment it is unfortunately not possible
> to mount the same CernVM-FS repo multiple times with different snapshots.


### Unmounting all images and main repos

Main repository is an actual CernVM-FS mountpoint, while Docker image mounts are
bind mounts of the main repository.

If for some reason there are stale mountpoints, you can unmount all the bind
mounts, and the main repository, with a single command:

```bash
sudo ./docker-cernvm --branch cernvm-devel.cern.ch unmount-all
```

Note that `umount-all` is a synonim for `unmount-all`, and `--branch` is
optional, defaulting to `cernvm-prod.cern.ch` if not specified.

The command will fail if it is not possible to unmount something for some
reason, *i.e.* if there are Docker containers currently using it.

Sample output:

```
Unmounting bind mount /var/lib/docker/aufs/diff/6f7834ff04d7cfaf93832e09790346c6d741968ec202fdf3aec881374d3faffa...ok
Unmounting main branch cernvm-devel.cern.ch...ok
Everything unmounted.
All operations executed successfully
```

This is a privileged operation like **mount**.


### Running the Docker CernVM container

Just use the ordinary `docker run` command. For instance:

```bash
docker run -i -t --rm -v /cvmfs/alice.cern.ch:/cvmfs/alice.cern.ch dberzano/cernvm
```

Note that we are having full read/write permissions inside the container thanks
to the Docker overlaying mechanism - and we don't even need to use it in
"privileged mode" as the filesystem is managed *outside* the container.

Please also note that `--rm` is used, meaning that the container will be
**destroyed** on exit. The container contains only the differences with respect
to the specific CernVM base we were using when we ran it, so, unless we are
explicitly choosing a CernVM snapshot, the diff layer may not make any sense if
used with different snapshots!

In the example above we are also mounting the ALICE CernVM-FS repository, which
is supposed to exist and be accessible from the hosting machine.

In practice we are relying on the host's caching mechanisms for CernVM-FS, which
is what makes this approach appealing: no internal cache inside the containers
means no privileged mode needed, and *actual*, *shared* and *persistent* cache
between all containers using the same CernVM-FS repositories.


## Condor inside Docker

The `condor-condor-cvm-docker-pilot` program is the Condor pilot to be run
inside the CernVM container. To do that, simply run:

```bash
docker-cernvm-run-pilot
```

The configuration is embedded in the Pilot (except the Condor secret). Edit it
according to your local configuration.

**Note:** pending documentation:

* How to configure Condor on the head node
* Run container in background and not interactively
* Separate configuration from Pilot script

**TODO**

* Container factory: start containers one after another, using Python possibly
* See [this](http://stackoverflow.com/questions/8241099/executing-tasks-in-parallel-in-python)
  for parallel processing, or just use Python threads
* Advantage: no install/configure Condor on the node. Everything isolated inside
  a container
* The same technology can be used as-is for opportunistic computing, volunteer
  computing and "ordinary" computing
* Quickly turn dedicated computing resources to something else, then revert back
* Always the freshest installation of the operating system
* Put a "drain mode" and possibility to change the number of containers on the
  fly in the "container factory"
* "Container factory" is indeed a nice name


## Notes and discussion

This section is about general notes and discussions behind this project. Please
take it as it is :-)


### Building the CernVM image

The CernVM image depends only from **scratch**. To build it, go to the build
directory and run the build command:

```bash
cd docker-build
docker build .
```

Pick the Image ID indicated on the last line:

```
Successfully built a81ca84cd833
```

Put the image in a repository (`dberzano/cernvm` in the example) and tag it.
Give it both the "latest" tag (no argument) and a numbered one (*e.g.* `0.2`):

```bash
docker tag -f a81ca84cd833 dberzano/cernvm
docker tag a81ca84cd833 dberzano/cernvm:0.2
```

**Note:** we are not using `-f` (for *force*) in the second command as we do not
want to accidentally overwrite an existing tag.

See how thin our image is with the command:

```
docker images
```

Only **801 B**!

```
REPOSITORY              TAG                 IMAGE ID            CREATED             VIRTUAL SIZE
dberzano/cernvm         0.2                 a81ca84cd833        7 minutes ago       801 B
dberzano/cernvm         latest              a81ca84cd833        7 minutes ago       801 B
```


### Cleaning up images

To clean up all the images not belonging to any repository:

```bash
docker images --no-trunc | grep '^<none>' | awk '{ print $3 }' | xargs -L 1 docker rmi
```

**Note:** please think twice before running the command!


### Where are my layers?

Start from listing the images:

```bash
docker images --no-trunc
```

Gives:

```
REPOSITORY              TAG                 IMAGE ID                                                           CREATED             VIRTUAL SIZE
dberzano/cernvm         0.2                 a81ca84cd83316f276d22a8dc1a3c4ae6917c5ab3243eff0eeed39bf4c89de88   10 minutes ago      801 B
dberzano/cernvm         latest              a81ca84cd83316f276d22a8dc1a3c4ae6917c5ab3243eff0eeed39bf4c89de88   10 minutes ago      801 B
```

Our 64 chars long ID is:

```
a81ca84cd83316f276d22a8dc1a3c4ae6917c5ab3243eff0eeed39bf4c89de88
```

Explore it (we are doing it as root):

```bash
cd /var/lib/docker
find . -name a81ca84cd83316f276d22a8dc1a3c4ae6917c5ab3243eff0eeed39bf4c89de88
```

Result:

```
4456996    4 drwxr-xr-x   2 root     root         4096 Mar 26 17:12 ./aufs/mnt/a81ca84cd83316f276d22a8dc1a3c4ae6917c5ab3243eff0eeed39bf4c89de88
4456997    4 drwxr-xr-x   2 root     root         4096 Mar 26 17:12 ./aufs/diff/a81ca84cd83316f276d22a8dc1a3c4ae6917c5ab3243eff0eeed39bf4c89de88
1182605    4 -rw-r--r--   1 root     root          195 Mar 26 17:12 ./aufs/layers/a81ca84cd83316f276d22a8dc1a3c4ae6917c5ab3243eff0eeed39bf4c89de88
2752525    4 drwx------   2 root     root         4096 Mar 26 17:12 ./graph/a81ca84cd83316f276d22a8dc1a3c4ae6917c5ab3243eff0eeed39bf4c89de88
```

We have four different "things" carrying this ID:

* **aufs/mnt**: an empty directory
* **aufs/diff**: a directory, also empty
* **aufs/layers**: a text file
* **graph**: another directory with a couple of files

It seems the first three are specific to the overlay mechanism used. We are
running our tests on Ubuntu 14.10, and [AUFS](http://aufs.sourceforge.net/) is
the method used.

It seems that for many reasons (including project maintenance issues),
[overlay will become the next default driver](http://blog.thestateofme.com/2015/03/09/using-overlay-file-system-with-docker-on-ubuntu/)
at some point.

There is [an interesting presentation](http://jpetazzo.github.io/assets/2015-03-03-not-so-deep-dive-into-docker-storage-drivers.html#1)
from Jérôme Petazzoni (@jpetazzo) illustrating the different overlay drivers
currently supported by Docker.

The **graph** directory contains a **json** file (expand it with
[this online tool](http://jsonformatter.curiousconcept.com/)) containing some
information, among which the things we have inputted in the Dockerfile. We can
also find the Parent Image ID, which appears to be:

```
8c2571508ad6679d94720215a2506fc73c8fe7c7504e5bb92418d2ea8aa22885
```

that should be the one coming from the `FROM` field of the Dockerfile. There is
also **layersize** file which contains the number 0 in our case.

We have found so far nothing useful for our use case. Let's explore the
**layers** text file. It contains more IDs:

```
8c2571508ad6679d94720215a2506fc73c8fe7c7504e5bb92418d2ea8aa22885
0acf4656547a78087706b2e508cc15f2391a31e1e6f338a64b3bcdf695f1a697
a76e7a615efa3dc21f0893307dbc7994492dad02bfae6e1f8df2d27967950abe
```

Each one corresponds to some overlapped iterations: and each one carries the
same structure with the **aufs/** directories, etc.

Those layers can be seen (in their short form) when building the image:

```
Step 0 : FROM scratch
 --->
Step 1 : MAINTAINER Dario Berzano, dario.berzano@cern.ch
 ---> Using cache
 ---> a76e7a615efa
Step 2 : COPY docker-entry-point.sh /.docker-entry-point.sh
 ---> Using cache
 ---> 0acf4656547a
Step 3 : CMD /bin/bash
 ---> Using cache
 ---> 8c2571508ad6
Step 4 : ENTRYPOINT /.docker-entry-point.sh
 ---> Using cache
 ---> a81ca84cd833
Successfully built a81ca84cd833
```

So, each line in the **layers** file corresponds to an instruction in the
Dockerfile, and:

* the **originating** layer is the one at the **bottom**,
* the **last-but-most-recent** is the one at the **top**,
* the **current** one is in the containing directory name.

The `COPY` command is the only one populating the filesystem (we are injecting
only one file).


### Hacking Docker for running CernVM

Concepts:

* CernVM 3 uses an overlay filesystem to make writable its root directory coming
  from CVMFS
* Docker uses an overlay mechanism too

We want to run CernVM containers in Docker, but we cannot use Docker's "volumes"
(given with the `VOLUME` directive of Dockerfiles, or the `-v` option to
`docker run`) because:

* they are bind-mounted too late: base system needs to be there in advance
* no overlay is provided (if they were born read-only, they stay read-only)

Idea:

* prepare a Dockerfile with only a `COPY` instruction placing some dummy
  placeholder
* look for this placeholder under the **/var/lib/docker/aufs/diff/ID**
  directory and mount CernVM over it

If it works, we will be able to run CernVM in a container by relying on the
overlay mechanism provided by Docker.


### Mounting the desired tag of CernVM

Tags of CernVM can be read from [CernVM Online](https://cernvm-online.cern.ch):
it embeds some Python bindings that return the full list of remotely available.

If we want to pick a certain tag, we have to pick:

* a **branch**, *i.e.* the CernVM-FS repository where the software will be
  downlaoded from,
* a **tag**, *i.e.* the snapshot number

For CernVM Production, the repository is `cernvm-prod.cern.ch`. The tag is
chosen by editing the file `/etc/cvmfs/config.d/cernvm-prod.cern.ch.local`:

```bash
CVMFS_CLAIM_OWNERSHIP=no
CVMFS_REPOSITORY_TAG=...
```

Note that `CVMFS_CLAIM_OWNERSHIP` has nothing to do with the tag. It is used to
retain user and group IDs from the remote instead of overriding them.

The second value, `CVMFS_REPOSITORY_TAG`, picks the latest tag if left empty or
unset.


#### Problems with multiple tags

It seems it is currently impossible to have different tags from the same
repository mounted at the same time:

* the configuration file is unique per repository,
* it is impossible to pass the tag as a command-line option

If we want to upgrade the CernVM Docker Image while having CernVM snapshots
running, we are forced to wait for all the containers to terminate, then unmount
and remount the production repository.

A solution must be found to this. Requests:

* Give an option to pick the tag from the command-line: that would be very
  convenient.
* Give the possibility to mount the same repository multiple times, with
  different options.
