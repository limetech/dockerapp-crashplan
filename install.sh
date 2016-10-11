#!/bin/bash

#########################################
##             INSTALLATION            ##
#########################################

# Upgrade Java
cat <<'EOT' > /etc/apt/sources.list
deb http://archive.ubuntu.com/ubuntu/ trusty main restricted
deb-src http://archive.ubuntu.com/ubuntu/ trusty main restricted
deb http://archive.ubuntu.com/ubuntu/ trusty-updates main restricted
deb-src http://archive.ubuntu.com/ubuntu/ trusty-updates main restricted
EOT
add-apt-repository -y -r ppa:no1wantdthisname/openjdk-fontfix
add-apt-repository -y ppa:webupd8team/java
apt-get update -qq
echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | /usr/bin/debconf-set-selections
apt-get install -y --force-yes oracle-java8-installer
apt-get install -y --force-yes oracle-java8-set-default
apt-get autoremove -y
apt-get clean -y
rm -rf /var/lib/apt/lists/* /var/cache/* /var/tmp/*

cat <<'EOT' > /etc/service/tomcat7/run
#!/bin/bash
exec 2>&1

mkdir -p /var/cache/tomcat7/Catalina/localhost/guacamole
touch /var/lib/tomcat7/logs/catalina.out

cd /var/lib/tomcat7
exec java -Djava.util.logging.config.file=/var/lib/tomcat7/conf/logging.properties \
          -Djava.util.logging.manager=org.apache.juli.ClassLoaderLogManager \
          -Djava.awt.headless=true -Xmx128m -XX:+UseConcMarkSweepGC \
          -Djava.endorsed.dirs=/usr/share/tomcat7/endorsed \
          -classpath /usr/share/tomcat7/bin/bootstrap.jar:/usr/share/tomcat7/bin/tomcat-juli.jar \
          -Dcatalina.base=/var/lib/tomcat7 -Dcatalina.home=/usr/share/tomcat7 \
          -Djava.io.tmpdir=/tmp/tomcat7-tomcat7-tmp org.apache.catalina.startup.Bootstrap start
EOT


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
echo "JAVACOMMON=${JAVACOMMON}" >> ${TARGETDIR}/install.vars

# Extract CrashPlan installer files
cd ${TARGETDIR}
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
sed -i 's|\$(ls -l \$0 \| awk '"'"'{ print \$NF }'"'"')|"/usr/local/crashplan/bin/CrashPlanDesktop"|g' /startapp.sh
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
