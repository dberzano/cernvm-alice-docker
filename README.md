Experimenting with Docker in CernVM and ALICE
=============================================

Scripts, utilities and documentation on using CernVM 3 from CVMFS in a Docker
container.


## Building the CernVM image

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


## Cleaning up images

To clean up all the images not belonging to any repository:

```bash
docker images --no-trunc | grep '^<none>' | awk '{ print $3 }' | xargs -L 1 docker rmi
```

**Note:** please think twice before running the command!


## Where are my layers?

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
