# RaspberrySetWirelessApWithEthernetRouting
Script that enables Raspberry Pi to create a wifi AP and act as a router to internet through the ethernet cable

Use with "sudo bash raspberrywifiap.sh" or make executable and run with "sudo ./raspberrywifiap.sh"
The script will install the necessary software, configure all files etc.
Based on a guide by Edoardo Paolo Scalafiotti @edoardo849
https://medium.com/@edoardo849/turn-a-raspberrypi-3-into-a-wifi-router-hotspot-41b03500080e

Once configured, your rpi will feature:
- WIFI security WPA2 (default WPA2 passphrase, please customize before running)
- WIFI modes G and N
- WIFI network with 192.168.66.X/255.255.255.0 IP configuration (customizable)
- ethernet in dhcp client mode in order to connect to your home router and provide access to internet
- routing of the AP clients to internet using ip IPv4 forwarding
- autostart of all services at boot
- some sanity checks and backups of files to avoid damage or losing of control
- most important configurations are customizable through script variables at the top of the script

{feedback,corrections,enhancements} welcome
alister.amo[at]eurecat.org
