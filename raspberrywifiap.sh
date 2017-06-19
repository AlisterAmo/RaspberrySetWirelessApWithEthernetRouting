#!/bin/bash
# script to enable raspberry 3 WIFI AP + internet hotspot through ethernet routing 
# alister amo - researcher of IT Security at Eurecat - @alisterwhitehat
# credits to @edoardo849 for the idea and the original manual recipe. I just automated it.
# ####################################################
## Some config variables. Set up accordingly. 
# DHCPD internal AP network config
# Don't use the same IP ranges than your router use or you will end up with network conflicts.
export RPI_LOCALIP="192.168.66.1"
export DHCPD_SUBNET="192.168.66.0"
export DHCPD_NETMASK="255.255.255.0"
export DHCPD_ADDRESSRANGE="192.168.66.10 192.168.66.100"
export DHCPD_BROADCAST="192.168.66.255"
export DHCPD_ROUTERS="$RPI_LOCALIP"
export DHCPD_DNS="8.8.8.8, 8.8.4.4"
# HOSTAPD WIFI hotspot config
export AP_SSID="rPI_AP"
export AP_WPAPASS="dontbeafoolandchangemeplease"
######################################################
# additional vars just for this script logging purposes and misc
# you don't need to change them 
export LOGFILE="${0}.log"
export ERRFILE="${0}.errors"
export ver="01"

# Some basic checks
if [ $EUID != "0" ]; then
  echo "Error checking effective UID. Please, use sudo or run from a root session"
  exit 1
fi 
## ifconfig wlan0 &> /dev/null && ifconfig eth0 &> /dev/null || echo "Error checking the existence of either eth0 or wlan0. Are you running from raspberry 3 with a proper raspbian kernel?" && exit 1
ping -c1 8.8.8.8 &> /dev/null || ( echo "Error checking internet connection. We need it to install sofware packages. Connect ethernet cable of raspberry pi to a router with inet access and try again"; exit 1)


# some useful functions
function warning {
echo "WARNING: $@" >> "$LOGFILE"
echo "WARNING: $@"
}

function echolog {
# echo "$@"
echo "$@" >> "$LOGFILE"
}

function cmd {
# ensures stdout and stderr output to configured file names
echolog "* "$(date)": Executing command --> $@"
$@ 1>> ${LOGFILE} 2>>${ERRFILE}
exitcode=$?
case $exitcode in
"0")
  echolog "  SUCCESS $exitcode"
  ;;
*)
  echolog "  FAILED WITH EXIT CODE $exitcode"
  ;;
esac
return $exitcode
}



function setconfigvalue {
# parameters: filename varname valuetoset
cmd sed -i "s,^\($2=\).*,\1$3," "$1"
return $?
}

function commentallmatching {
# parameters: filename "regex"
# use "regex" to search lines by literal text patters
cmd sed -i '/'"$2"'/ s/^/# /' "$1"
return $?
}

function uncommentallmatching {
# parameters: filename "regex"
# use "regex" to search lines by literal text patterns
# only matches lines starting by #, but
# it wont uncomment successfully if two or more # exist, so take care
cmd sed -i '/^#.*'"${2}"'/ s/^#//' "$1"
return $?
}

function isinfile {
# matches text in file
# returns 1 if not found
# returns 0 if found
grep -q "$1" "$2"
echo $?
}

# start the config work
# packet repo update and software packages install
echo "RASPBERRY PI 3 RASPBIAN AP CONFIGURATOR SCRIPT v.$ver STARTING..."
echo "Ensuring that needed software is installed..."
cmd apt-get -y update  
cmd apt-get -y install hostapd isc-dhcp-server
# dhcp server config - part 1
echo "Configuring DHCP server's dhcpd.conf file values..."
cmd cp /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.default
commentallmatching /etc/dhcp/dhcpd.conf "option domain-name"
uncommentallmatching /etc/dhcp/dhcpd.conf "authoritative;" 
networkconfigured=$(isinfile "$DHCPD_SUBNET" "/etc/dhcp/dhcpd.conf")
case $networkconfigured in
"1")
  # not found. we expect that dhcpd.conf file does not have this network defined already  
  output=$(echo "subnet $DHCPD_SUBNET netmask $DHCPD_NETMASK {
    range ${DHCPD_ADDRESSRANGE};
    option broadcast-address ${DHCPD_BROADCAST};
    option routers ${DHCPD_ROUTERS};
    default-lease-time 600;
    max-lease-time 7200;
    option domain-name \"local\";
    option domain-name-servers ${DHCPD_DNS};
}" | tee -a /etc/dhcp/dhcpd.conf)
echolog "Appended content to file /etc/dhcp/dhcpd.conf:"
echolog $output
echolog "<EOF>"
;;
"0")
  # found. oops...
  warning "Omitting subnet config in dhcpd.conf since a network definition with the same subnet has been found."
  warning "Please, DHCPDs network definitions or change values in this script accordingly."
;;
esac
# dhcp server config - part 2
echo "Configuring DHCP server's isc-dhcp-server file values..."
setconfigvalue "/etc/default/isc-dhcp-server" "INTERFACES" "wlan0"
# network interface config
echo "Network interface config..."
echo "IMPORTANT: Raspberry's ethernet IP config will be set to automatic (DHCP client)"
echo "           This internface NEEDS to be connected to your internet router"
echo "           And if you are connected through SSH via raspberry's wireless interface," 
echo "           you WILL loose connection NOW"
echo ""
echo "Hit CTRL+C now if you are not correctly prepared. You have 5 seconds..."
sleep 5
echo "Proceeding... Old version of interfaces file will be backed up to /etc/network/interfaces.backup"
cmd "ifdown wlan0"
cmd "cp /etc/network/interfaces /etc/network/interfaces.backup"

output=$(echo "source-directory /etc/network/interfaces.d

auto lo
iface lo inet loopback

allow-hotwplug eth0
iface eth0 inet dhcp

allow-hotplug wlan0 
iface wlan0 inet static
  address $RPI_LOCALIP
  netmask $DHCPD_NETMASK
  post-up iw dev \$IFACE set power_save off" | tee /etc/network/interfaces)

echolog "New contents of file /etc/network/interfaces:"
echolog "$output"
echolog "<EOF>"
cmd ifconfig wlan0 $RPI_LOCALIP

# HOSTAPD config
# Some configurations are not customizable through variables, 
# namely WIFI security related (WPA2 CCMP)
# of performance related (modes G and N enabled), channel auto 
echo "Hostapd config..."
output=$(echo "interface=wlan0
ssid=$AP_SSID
hw_mode=g
ieee80211n=1
channel=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=$AP_WPAPASS
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP" | tee /etc/hostapd/hostapd.conf)
echolog "New contents of file /etc/hostapd/hostapd.conf:"
echolog "$output"
echolog "<EOF>"
# NAT config
echolog "NAT config..."
cmd cp /etc/sysctl.conf /etc/sysctl.conf.backup
output=$(echo "net.ipv4.ip_forward=1" | tee -a /etc/sysctl.conf)
echolog "Appended content to file /etc/sysctl.conf:"
echolog "$output"
echolog "<EOF>"
cmd sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
cmd iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
cmd iptables -A FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
cmd iptables -A FORWARD -i wlan0 -o eth0 -j ACCEPT
cmd sh -c "iptables-save > /etc/iptables.ipv4.nat"
output=$(echo "up iptables-restore < /etc/iptables.ipv4.nat" | tee -a /etc/network/interfaces)
echolog "Appended content to file /etc/network/interfaces:"
echolog "$output"
echolog "<EOF>"
# Daemons autorun final config
echo "Configuring daemons to run automatically at boot..."
output=$(echo "DAEMON_CONF=/etc/hostapd/hostapd.conf" | tee -a /etc/default/hostapd)
echolog "Appended to file /etc/default/hostapd:"
echolog "$output"
echolog "<EOF>"
cmd service hostapd start
cmd service isc-dhcp-server start
cmd update-rc.d hostapd enable
cmd update-rc.d isc-dhcp-server enable
echo "FINISHED! Please, reboot the RPI"
