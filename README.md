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


## Cleaning up images

To clean up all the images not belonging to any repository:

```bash
docker images --no-trunc | grep '^<none>' | awk '{ print $3 }' | xargs -L 1 docker rmi
```

**Note:** please think twice before running the command!
