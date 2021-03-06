#!/bin/sh

DIALOG="whiptail"

$DIALOG --title "Ubilling installation" --yesno "This wizard helps you to install Stargazer and Ubilling of latest versions to CLEAN(!) Ubuntu 12.04LTS distribution" 10 40
AGREE=$?
clear
case $AGREE in
0)
clear
$DIALOG --title "LAN interface"  --inputbox "Enter interface name that interracts with your INTERNAL network (for example eth0)" 20 50 2> /tmp/ubiface
clear
$DIALOG --title "Users network"  --inputbox "Enter users network (for example 172.16.0.0)" 8 40 2> /tmp/ubnetw
clear
$DIALOG --title "Users network CIDR"  --inputbox "Enter users network CIDR mask (for example 24 or 19)" 8 40 2> /tmp/ubcidr
clear
$DIALOG --title "MySQL password"  --inputbox "Enter new MySQL password for user root" 8 40 2> /tmp/ubmypas
clear
$DIALOG --title "Ubilling server IP"  --inputbox "Enter IP address of this server" 8 40 2> /tmp/ubip
clear
$DIALOG --title "New stargazer admin password"  --inputbox "Enter new password for stargazer administrator" 8 40 2> /tmp/ubstgpass
clear
$DIALOG --title "Remote NAS encription key"  --inputbox "Enter password for rscriptd NAS servers" 8 40 2> /tmp/ubrsd
clear
$DIALOG --title "External interface name"  --inputbox "Input external interface name for setup NAT (for example eth1)" 8 40 2> /tmp/ubextif
clear
$DIALOG --title "External interface IP"  --inputbox "Input external interface IP for setup NAT" 8 40 2> /tmp/ubextip
clear



LAN_IF=`cat /tmp/ubiface`
MYSQL_PASSWD=`cat /tmp/ubmypas`
LAN_NETW=`cat /tmp/ubnetw`
LAN_CIDR=`cat /tmp/ubcidr`
STG_PASS=`cat /tmp/ubstgpass`
RSD_PASS=`cat /tmp/ubrsd`
EXT_IF=`cat /tmp/ubextif`
EXT_IP=`cat /tmp/ubextip`
SERVER_IP=`cat /tmp/ubip`

wget https://raw.github.com/nightflyza/ubuntustaller/master/batchsetup.sh
# params:
# batchsetup.sh MYSQL_PASSWD STG_PASS RSD_PASS LAN_IFACE LAN_NET LAN_MASK WAN_IFACE WAN_IP
bash ./batchsetup.sh ${MYSQL_PASSWD} ${STG_PASS} ${RSD_PASS}  ${LAN_IF} ${LAN_NETW} ${LAN_CIDR} ${EXT_IF} ${EXT_IP} &> /var/log/ubuntustaller.log &


{
        i="0"
        while (true)
        do
            proc=$(ps aux | grep -v grep | grep -e "batchsetup.sh")
            if [[ "$proc" == "" ]]; then break; fi
            sleep 1
            echo $i
            i=$(expr $i + 1)
        done
        echo 100
        sleep 2
} | $DIALOG --title "Installing Ubilling" --gauge "Please wait..." 8 78 0

$DIALOG --title "Installation complete" --msgbox "Now you can access your web-interface by address http://${SERVER_IP}/billing/ with login and password: admin/demo. Please reboot your server to check correct startup of all services" 15 50
echo "Ubilling"
cat /var/www/billing/RELEASE

;;
1)
echo "Ubilling installation interrupted"
esac


