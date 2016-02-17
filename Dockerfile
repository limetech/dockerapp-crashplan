FROM phusion/baseimage:0.9.18
MAINTAINER Lime Technology <erics@lime-technology.com>
#Based on the work of gfjardim <gfjardim@gmail.com>

#########################################
##        ENVIRONMENTAL CONFIG         ##
#########################################
# Set correct environment variables
ENV CP_VERSION="4.5.2"
ENV USER_ID="0" GROUP_ID="0" TERM="xterm" WIDTH="1280" HEIGHT="720"

# Use baseimage-docker's init system
CMD ["/sbin/my_init"]

#########################################
##         RUN INSTALL SCRIPT          ##
#########################################
ADD ./files /files/
RUN /bin/bash /files/install.sh

#########################################
##         EXPORTS AND VOLUMES         ##
#########################################
VOLUME /data /config
EXPOSE 4243 4242 4280