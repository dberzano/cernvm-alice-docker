#!/bin/sh
echo '*** Welcome to CernVM ***'
echo '* Creating /etc'
rsync -a --ignore-existing /.etc.cvmro/ /etc/
export USER=root
export HOME=/root
echo "* Current user: $USER"
echo "* Current home directory: $HOME"
cd "$HOME"
echo "* Executing command: $*"
exec "$@"
