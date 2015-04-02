FROM scratch

MAINTAINER Dario Berzano, dario.berzano@cern.ch

# Dummy empty file
COPY THIS_IS_A_CERNVM_MOUNT_POINT /THIS_IS_A_CERNVM_MOUNT_POINT

# ENTRYPOINT is the "interpreter" that runs any command provided on the command line via "docker
# run". If no initial command is provided when launching the container, the command specified by CMD
# is executed.
#
# From https://docs.docker.com/reference/builder/
#
# The CMD instruction has three forms:
#
# CMD ["executable","param1","param2"] (exec form, this is the preferred form)
# CMD ["param1","param2"] (as default parameters to ENTRYPOINT)
# CMD command param1 param2 (shell form)
#
# Here we are not using ENTRYPOINT but CMD instead. If we provide a command, it will be executed in
# place of CMD, instead of being passed to ENTRYPOINT.
#ENTRYPOINT [ "/bin/bash" ]
CMD [ "/bin/bash" ]
