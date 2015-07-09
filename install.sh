#!/bin/bash

DESTDIR=/usr/local/bsdp
SBINDIR="$DESTDIR"/sbin
LIBDIR="$DESTDIR"/lib
CONFDIR="$DESTDIR"/etc

NBUSER=netboot
NBPASS=appleNB
IMAGEPATH=/srv/NetBoot/NetBootSP
CLIENTPATH=/srv/NetBoot/NetBootClients

SRCDIR=`dirname "$0"`

if [ -e "/etc/os-release" ]; then
	. /etc/os-release
fi

if [ -z "$ID" ] && [ -e "/etc/system-release-cpe" ]; then
	ID=`cat /etc/system-release-cpe | cut -d : -f 3`
fi

if [ "$ID" != "ubuntu" ] && [ "$ID" != "redhat" ] && [ "$ID" != "centos" ]; then
	echo "Error: Did not detect a valid Ubuntu/RedHat/CentOS install."
	exit 1
fi

#
# Install required software.
#
if [ "$ID" == "ubuntu" ]; then
	PACKAGES=( tftpd-hpa apache2 apache2-utils netatalk nfs-kernel-server python-configparser )

	TFTP=tftpd-hpa
	TFTPCONF=/etc/default/tftpd-hpa

	AFP=netatalk
	AFPCONF=/etc/netatalk/AppleVolumes.default

	HTTP=apache2
	HTTPCONF=/etc/apache2/sites-available/000-netboot.conf
	HTTPERROR=/index.html

	NFS=nfs-kernel-server
	NFSEXPORT=/etc/exports

	apt-get --no-install-recommends install -y ${PACKAGES[@]}

	touch "$HTTPCONF"
	a2ensite "$(basename "$HTTPCONF")"
else
	PACKAGES=( avahi httpd nfs-utils tftp-server netatalk )
	EPEL=http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm

	TFTP=xinetd
	TFTPCONF=/etc/xinetd.d/tftp

	AFP=netatalk
	AFPCONF=/etc/netatalk/AppleVolumes.default

	HTTP=httpd
	HTTPCONF=/etc/httpd/conf.d/netboot.conf
	HTTPERROR=/error/noindex.html

	NFS=nfs
	NFSEXPORT=/etc/exports

	sed -i "s/SELINUX=.*/SELINUX=permissive/" /etc/selinux/config
	echo 0 > /selinux/enforce

	yum --disablerepo=\* localinstall -y $EPEL
	yum install -y ${PACKAGES[@]}
	chkconfig xinetd on
	chkconfig tftp on
	chkconfig netatalk on
	chkconfig httpd on
	chkconfig nfs on
	chkconfig iptables off
	chkconfig ip6tables off
	service iptables stop
	service ip6tables stop
	service xinetd start
	service messagebus start
	service avahi-daemon start
	service netatalk start
	service httpd start
	service rpcbind start
fi

#
# Created NetBoot directories.
#
mkdir -p "$IMAGEPATH" "$CLIENTPATH"
chgrp adm "$IMAGEPATH" "$CLIENTPATH"
chmod g+w "$IMAGEPATH" "$CLIENTPATH"
chmod +s "$IMAGEPATH" "$CLIENTPATH"

#
# Create NetBoot user.
#
useradd -M "$NBUSER"
echo "$NBUSER:$NBPASS" | chpasswd

#
# Configure tftp.
#
sed -i "s:/var/lib/tftpboot:$IMAGEPATH:" "$TFTPCONF"
service $TFTP restart

#
# Configure netatalk.
#
sed -i "s:^~:# ~:" "$AFPCONF"
sed -i "/\(^# ~.*$\)/ a\
$IMAGEPATH \"NetBootSP\" allow:@adm" "$AFPCONF"
sed -i "/.*\"NetBootSP\".*/ a\
$CLIENTPATH \"NetBootClients\" allow:$NBUSER,@adm" "$AFPCONF"
service $AFP restart

#
# Configure apache.
#
if [ "$ID" == "ubuntu" ]; then
	echo "Alias /NetBoot/ \"$IMAGEPATH/\"
<Directory \"$IMAGEPATH/\">
    Options Indexes FollowSymLinks MultiViews
    AllowOverride None
    Require all granted
</Directory>

<LocationMatch \"/NetBoot/\">
    Options -Indexes
</LocationMatch>" > "$HTTPCONF"
else
	echo "Alias /NetBoot/ \"$IMAGEPATH/\"
<Directory \"$IMAGEPATH/\">
    Options Indexes FollowSymLinks MultiViews
    AllowOverride None
    Order allow,deny
    Allow from all
</Directory>

<LocationMatch \"/NetBoot/\">
    Options -Indexes
    ErrorDocument 403 /error/noindex.html
</LocationMatch>" > "$HTTPCONF"
fi
service $HTTP reload

#
# Configure nfs.
#
echo "$IMAGEPATH *(ro,no_subtree_check,no_root_squash,insecure)" >> "$NFSEXPORT"
exportfs -a
service $NFS start

#
# Install standard files.
#
mkdir -p "$LIBDIR" "$SBINDIR"
mv -f "$SRCDIR"/bsdp.py "$LIBDIR"
mv -f "$SRCDIR"/dhcp.py "$LIBDIR"
mv -f "$SRCDIR"/interfaces.py "$LIBDIR"
mv -f "$SRCDIR"/bsdpd.py "$SBINDIR"
chmod +x "$SBINDIR"/bsdpd.py

#
# Create config file if one is not present.
#
if [ ! -e "$CONFDIR"/bsdp.conf ]; then
	mkdir -p "$CONFDIR"
	echo "[bsdp]
netbootuser = $NBUSER
netbootpass = $NBPASS
imagepath = $IMAGEPATH
clientpath = $CLIENTPATH" > "$CONFDIR"/bsdp.conf 
fi

#
# Install init script.
#
if [ "$ID" == "ubuntu" ]; then
	mv -f "$SRCDIR"/ubuntu.init /etc/init/bsdpd.conf
else
	mv -f "$SRCDIR"/rhel.init /etc/rc.d/init.d/bsdpd
	chmod +x /etc/rc.d/init.d/bsdpd
	chkconfig --add bsdpd
	chkconfig bsdpd on
fi

#
# Start service.
#
service bsdpd start

rm -rf "$SRCDIR"

exit 0