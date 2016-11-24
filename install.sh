#!/bin/bash

#########################################
##             INSTALLATION            ##
#########################################

# Install Crashplan
APP_BASENAME=CrashPlan
DIR_BASENAME=crashplan
TEMPDIR=/tmp/crashplan-install
TARGETDIR=/usr/local/crashplan
BINSDIR=/usr/local/bin
MANIFESTDIR=/backups
INITDIR=/etc/init.d
RUNLEVEL=$(who -r | sed -e 's/^.*\(run-level [0-9]\).*$/\1/' | cut -d \  -f 2)
RUNLVLDIR=/etc/rc${RUNLEVEL}.d
JAVACOMMON=$(which java)

# Downloading Crashplan
wget -nv http://download.code42.com/installs/linux/install/CrashPlan/CrashPlan_4.8.0_Linux.tgz -O - | tar -zx -C /tmp

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
echo "INSTALLDATE=$(date +%Y%m%d)" >> ${TARGETDIR}/install.vars
cat ${TEMPDIR}/install.defaults >> ${TARGETDIR}/install.vars
echo "JAVACOMMON=${TARGETDIR}/jre/bin/java" >> ${TARGETDIR}/install.vars

cd ${TARGETDIR}

#download java
if [[ $JAVACOMMON == "DOWNLOAD" ]]; then
	if [[ $PARCH == "x86_64" ]]; then
		JVMURL="http://download.code42.com/installs/proserver/jre/jre-linux-x64-1.8.0_72.tgz"
	else
		JVMURL="http://download.code42.com/installs/proserver/jre/jre-linux-i586-1.8.0_72.tgz"
	fi
	JVMFILE=`basename ${JVMURL}`
	if [[ -f ${JVMFILE} ]]; then
		echo ""
		echo "Download of the JVM found. We'll try to use it, but if it's only a partial"
		echo "copy of the file then this will fail. If that happens please remove the file"
		echo "and try again."
		echo "JRE Archive: ${JVMFILE}"
		echo ""
	else
	
	    # Start by looking for wget
	    WGET_PATH=`which wget 2> /dev/null`
	    if [[ $? == 0 ]]; then
			echo "    downloading the JRE using wget"
			$WGET_PATH $JVMURL
			if [[ $? != 0 ]]; then
				echo "Unable to download JRE; please check network connection"
				exit 1
			fi
	    else

			CURL_PATH=`which curl 2> /dev/null`
			if [[ $? == 0 ]]; then
		    	echo "    downloading the JRE using curl"
		    	$CURL_PATH -L $JVMURL -o `basename $JVMURL`
				if [[ $? != 0 ]]; then
					echo "Unable to download JRE; please check network connection"
					exit 1
				fi
			else
		    	echo "Could not find wget or curl.  You must install one of these utilities"
		    	echo "in order to download a JVM"
		    	exit 1
			fi
	    fi
	fi
	
	# Extract into ./jre
	tar -xozf "${JVMFILE}"
	echo "Java Installed."
fi

# Extract CrashPlan installer files
cat $(ls ${TEMPDIR}/*_*.cpi) | gzip -d -c - | cpio -i --no-preserve-owner

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
cp ${TEMPDIR}/scripts/run.conf ${TARGETDIR}/bin

# Add desktop startup script
cp ${TEMPDIR}/scripts/CrashPlanDesktop /startapp.sh
sed -i 's|"\$SCRIPTDIR/.."|\$(dirname $SCRIPTDIR)|g' /startapp.sh

# Fix permissions
chmod -R u-x,go-rwx,go+u,ugo+X ${TARGETDIR}
chown -R nobody ${TARGETDIR} /var/lib/crashplan

# Disable auto update
cat <<'EOT' > ${TARGETDIR}/upgrade/startLinux.sh
#!/bin/sh

# in-app updates are disabled
EOT

# Updated Xvnc config (remove existing lock file)
cat <<'EOT' > /etc/service/Xvnc/run
#!/bin/bash
exec 2>&1
WD=${WIDTH:-1280}
HT=${HEIGHT:-720}

rm -f /tmp/.X1-lock &>/dev/null

exec /sbin/setuser nobody Xvnc4 :1 -geometry ${WD}x${HT} -depth 16 -rfbwait 30000 -SecurityTypes None -rfbport 5901 -bs -ac \
                   -pn -fp /usr/share/fonts/X11/misc/,/usr/share/fonts/X11/75dpi/,/usr/share/fonts/X11/100dpi/ \
                   -co /etc/X11/rgb -dpi 96
EOT

# Updated Guacamole config
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
rm -rf ${TEMPDIR}
