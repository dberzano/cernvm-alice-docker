FROM scratch

MAINTAINER Dario Berzano, dario.berzano@cern.ch

COPY docker-entry-point.sh /docker-entry-point.sh

# With the following form, ENTRYPOINT is the "interpreter" that runs any command
# provided on the command line via "docker run".
#
# If no command is provided, the command specified by CMD is executed.
CMD [ "/bin/bash" ]
ENTRYPOINT [ "/docker-entry-point.sh" ]

# From https://docs.docker.com/reference/builder/
#
# The CMD instruction has three forms:
#
# CMD ["executable","param1","param2"] (exec form, this is the preferred form)
# CMD ["param1","param2"] (as default parameters to ENTRYPOINT)
# CMD command param1 param2 (shell form)
