#!/bin/bash

#########################################
##             INSTALLATION            ##
#########################################

# Install Crashplan
APP_BASENAME=CrashPlan
DIR_BASENAME=crashplan
TARGETDIR=/usr/local/crashplan
BINSDIR=/usr/local/bin
MANIFESTDIR=/backups
INITDIR=/etc/init.d
RUNLEVEL=`who -r | sed -e 's/^.*\(run-level [0-9]\).*$/\1/' | cut -d \  -f 2`
RUNLVLDIR=/etc/rc${RUNLEVEL}.d
JAVACOMMON=`which java`

# Downloading Crashplan
wget -nv http://download.code42.com/installs/linux/install/CrashPlan/CrashPlan_4.2.0_Linux.tgz -O - | tar -zx -C /tmp

# Installation directory
cd /tmp/CrashPlan-install
INSTALL_DIR=`pwd`

# Make the destination dirs
mkdir -p ${TARGETDIR}
mkdir -p /var/lib/crashplan

# create a file that has our install vars so we can later uninstall
echo "" > ${TARGETDIR}/install.vars
echo "TARGETDIR=${TARGETDIR}" >> ${TARGETDIR}/install.vars
echo "BINSDIR=${BINSDIR}" >> ${TARGETDIR}/install.vars
echo "MANIFESTDIR=${MANIFESTDIR}" >> ${TARGETDIR}/install.vars
echo "INITDIR=${INITDIR}" >> ${TARGETDIR}/install.vars
echo "RUNLVLDIR=${RUNLVLDIR}" >> ${TARGETDIR}/install.vars
NOW=`date +%Y%m%d`
echo "INSTALLDATE=$NOW" >> ${TARGETDIR}/install.vars
cat ${INSTALL_DIR}/install.defaults >> ${TARGETDIR}/install.vars
echo "JAVACOMMON=${JAVACOMMON}" >> ${TARGETDIR}/install.vars

# Definition of ARCHIVE occurred above when we extracted the JAR we need to evaluate Java environment
ARCHIVE=`ls ./*_*.cpi`
cd ${TARGETDIR}
cat "${INSTALL_DIR}/${ARCHIVE}" | gzip -d -c - | cpio -i --no-preserve-owner
cd ${INSTALL_DIR}

# Update the configs for file storage
if grep "<manifestPath>.*</manifestPath>" ${TARGETDIR}/conf/default.service.xml > /dev/null; then
	sed -i "s|<manifestPath>.*</manifestPath>|<manifestPath>${MANIFESTDIR}</manifestPath>|g" ${TARGETDIR}/conf/default.service.xml
else
	sed -i "s|<backupConfig>|<backupConfig>\n\t\t\t<manifestPath>${MANIFESTDIR}</manifestPath>|g" ${TARGETDIR}/conf/default.service.xml
fi

# Remove the default backup set
if grep "<backupSets>.*</backupSets>" ${TARGETDIR}/conf/default.service.xml > /dev/null; then
    sed -i "s|<backupSets>.*</backupSets>|<backupSets></backupSets>|g" ${TARGETDIR}/conf/default.service.xml
fi

# Install the control script for the service
cp scripts/run.conf ${TARGETDIR}/bin

# Add desktop startup script
cp scripts/CrashPlanDesktop  /startapp.sh
sed -i 's|"\$SCRIPTDIR/.."|\$(dirname $SCRIPTDIR)|g' /startapp.sh

# Fix permissions
chmod -R u-x,go-rwx,go+u,ugo+X ${TARGETDIR}
chown -R nobody ${TARGETDIR} /var/lib/crashplan

# Disable auto update
chmod -R -x ${TARGETDIR}/upgrade/*

cat <<'EOT' > /etc/guacamole/noauth-config.xml
<configs>
    <config name="GUI_APPLICATION" protocol="rdp">
        <param name="hostname" value="127.0.0.1" />
        <param name="port" value="3389" />
        <param name="username" value="nobody" />
        <param name="password" value="PASSWD" />
        <param name="color-depth" value="16" />
    </config>
</configs>
EOT

#########################################
##                 CLEANUP             ##
#########################################

# Remove install data
rm -rf ${INSTALL_DIR}
