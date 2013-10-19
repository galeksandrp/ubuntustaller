#!/bin/sh

#config section
#===============================================
MYSQL_PASSWD="changemedb"
STG_PASS="stgpass"
LAN_IFACE="eth0"
LAN_NET="172.16.0.0/24"
WAN_IFACE="eth1"
WAN_IP="10.0.3.15"

#===============================================


#setting mysql passwords
echo mysql-server-5.5 mysql-server/root_password password ${MYSQL_PASSWD} | debconf-set-selections
echo mysql-server-5.5 mysql-server/root_password_again password ${MYSQL_PASSWD} | debconf-set-selections

#deps install
apt-get -y install mysql-server-core-5.5 mysql-client-core-5.5 libmysqlclient18 libmysqlclient-dev apache2 mysql-server expat libexpat-dev php5-cli libapache2-mod-php5 php5-mysql dhcp3-server build-essential bind9 bandwidthd softflowd
#apache php enabling 
a2enmod php5
apachectl restart
#add apache childs to sudoers
echo "User_Alias BILLING = www-data" >> /etc/sudoers
echo "BILLING          ALL = NOPASSWD: ALL" >> /etc/sudoers
#linking bandwidthd htdocs
ln -fs /var/lib/bandwidthd/htdocs/ /var/www/band
#installing ipset
apt-get -y install ipset
modprobe ip_set
#htb init script setup
wget https://raw.github.com/nightflyza/ubuntustaller/master/htb.init
cp htb.init /etc/init.d/htb
chmod a+x /etc/init.d/htb
update-rc.d htb defaults
mkdir /etc/sysconfig
mkdir /etc/sysconfig/htb
cd /etc/sysconfig/htb 

touch ${LAN_IFACE}
touch ${WAN_IFACE}
touch ${LAN_IFACE}-2.root
touch ${WAN_IFACE}-2.root

echo "DEFAULT=0" >> ${LAN_IFACE}
echo "R2Q=100" >> ${LAN_IFACE}
echo "DEFAULT=0" >> ${WAN_IFACE}
echo "R2Q=100" >> ${WAN_IFACE}
echo "RATE=100Mbit" >> ${LAN_IFACE}-2.root
echo "CEIL=100Mbit" >> ${LAN_IFACE}-2.root
echo "RATE=100Mbit" >> ${WAN_IFACE}-2.root
echo "CEIL=100Mbit" >> ${WAN_IFACE}-2.root

service htb restart

#stargazer setup
mkdir /root/stargazer
cd /root/stargazer
wget http://stargazer.net.ua/download/server/2.408/stg-2.408.tar.gz
tar zxvf stg-2.408.tar.gz
cd stg-2.408/projects/stargazer/
./build
make install
cd ../sgconf && ./build && make && make install
cd ../sgconf_xml/ && ./build && make && make install

#updating stargazer config
wget https://raw.github.com/nightflyza/ubuntustaller/master/stargazer.conf
cp -R stargazer.conf /etc/stargazer/
perl -e "s/newpassword/${MYSQL_PASSWD}/g" -pi /etc/stargazer/stargazer.conf

#updating rules file
echo "ALL     0.0.0.0/0       DIR0" > /etc/stargazer/rules

#starting stargazer first time
stargazer
mysql -u root -p${MYSQL_PASSWD} stg -e "SHOW TABLES"
#updating admin password
/usr/sbin/sgconf_xml -s localhost -p 5555 -a admin -w 123456 -r " <ChgAdmin Login=\"admin\" password=\"${STG_PASS}\" /> "
killall stargazer

#downloading and installing Ubilling
cd /var/www/
mkdir billing
cd billing
wget http://ubilling.net.ua/ub.tgz
tar zxvf ub.tgz
chmod -R 0777 content/ config/ multinet/ exports/ remote_nas.conf
#apply dump
cat /var/www/billing/docs/test_dump.sql | mysql -u root -p${MYSQL_PASSWD} stg
mysql -u root -p${MYSQL_PASSWD} stg -e "SHOW TABLES"
#updating passwords
perl -e "s/mylogin/root/g" -pi ./config/mysql.ini
perl -e "s/newpassword/${MYSQL_PASSWD}/g" -pi ./config/mysql.ini
perl -e "s/mylogin/root/g" -pi ./userstats/config/mysql.ini
perl -e "s/newpassword/${MYSQL_PASSWD}/g" -pi ./userstats/config/mysql.ini

#hotfix 2.408 admin permissions trouble
wget https://raw.github.com/nightflyza/ubuntustaller/master/admin_rights_hotfix.sql
cat admin_rights_hotfix.sql | mysql -u root  -p stg --password=${MYSQL_PASSWD}
perl -e "s/123456/${STG_PASS}/g" -pi ./config/billing.ini
perl -e "s/123456/${STG_PASS}/g" -pi ./userstats/config/userstats.ini

#updating linux specific things


sed -i "s/\/usr\/local\/bin\/sudo/\/usr\/bin\/sudo/g" ./config/billing.ini
sed -i "s/\/usr\/bin\/top -b/\/usr\/bin\/top -b -n 1/g" ./config/billing.ini
sed -i "s/\/usr\/bin\/grep/\/bin\/grep/g" ./config/billing.ini
sed -i "s/\/usr\/local\/etc\/rc.d\/isc-dhcpd/\/etc\/init.d\/dhcp3-server/g" ./config/billing.ini
sed -i "s/\/sbin\/ping/\/bin\/ping/g" ./config/billing.ini
sed -i "s/\/var\/log\/messages/\/var\/log\/dhcpd.log/g" ./config/alter.ini

#setting up dhcpd
ln -fs /var/www/billing/multinet/ /etc/dhcp/multinet
echo "!dhcpd" >> /etc/rsyslog.d/50-default.conf
echo " *.*                       /var/log/dhcpd.log" >> /etc/rsyslog.d/50-default.conf
touch /var/log/dhcpd.log
chmod 777 /var/log/dhcpd.log
service rsyslog restart
echo "INTERFACES=\"${LAN_IFACE}"\" > /etc/default/isc-dhcp-server
sed -i "s/\/etc\/dhcp\/dhcpd.conf/\/var\/www\/billing\/multinet\/dhcpd.conf/g" /etc/init/isc-dhcp-server.conf
sed -i "s/\/usr\/local\/etc/\/var\/www\/billing/g"  /var/www/billing/config/dhcp/subnets.template
wget https://raw.github.com/nightflyza/ubuntustaller/master/usr.sbin.dhcpd
cp -f usr.sbin.dhcpd /etc/apparmor.d/
apparmor_parser -r /etc/apparmor.d/usr.sbin.dhcpd
service isc-dhcp-server restart

#extractiong presets
cp -f /var/www/billing/docs/presets/Linux/etc/* /etc/stargazer/
chmod a+x /etc/stargazer/*
ln -fs /var/www/billing/remote_nas.conf /etc/stargazer/remote_nas.conf
sed -i "s/newpassword/${MYSQL_PASSWD}/g" /etc/stargazer/config

#updating init.d
wget https://raw.github.com/nightflyza/ubuntustaller/master/rc.ubilling
cp -f rc.ubilling /etc/init.d/ubilling
chmod a+x /etc/init.d/ubilling
sed -i "s/EXTERNAL_IP/${WAN_IP}/g" /etc/init.d/ubilling
sed -i "s/EXTERNAL_IFACE/${WAN_IFACE}/g" /etc/init.d/ubilling
sed -i "s/INTERNAL_NETWORK/${LAN_NET}/g" /etc/init.d/ubilling
sed -i "s/INTERNAL_IFACE/${LAN_IFACE}/g" /etc/init.d/ubilling
sed -i "s/ / /g" /etc/init.d/ubilling
update-rc.d ubilling defaults
