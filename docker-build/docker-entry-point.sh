#!/bin/sh

# To be copied to the container using COPY and to be used as the entrypoint by
# means of ENTRYPOINT. This is configured to correctly run the default command
# provided by CMD, if no other command is passed to "docker run".

# We are using CernVM thanks to Docker "volumes", but Docker creates /etc with
# some files (resolv.conf, hostname, host) that we need. We therefore mount the
# /etc directory in readonly on another location, and we copy all of its files,
# except the ones created by Docker, in the real /etc. We can afford it because
# its size is ~10 MB
rsync -a --ignore-existing /.etc.cvmro/ /etc/

# We need to export some variables and move to home
export USER=root
export HOME=/root
cd "$HOME"

# Finally, execute the given or default command, and pass it our PID
exec "$@"
