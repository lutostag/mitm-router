#!/bin/bash

AP_IFACE="${AP_IFACE:-wlan0}"
INTERNET_IFACE="${INTERNET_IFACE:-eth0}"
SSID="${SSID:-Public}"
MAC="${MAC:-random}"

# SIGTERM-handler
term_handler() {

  # remove iptable entries
  iptables -t nat -D POSTROUTING -o "$INTERNET_IFACE" -j MASQUERADE
  iptables -D FORWARD -i "$INTERNET_IFACE" -o "$AP_IFACE" -m state --state RELATED,ESTABLISHED -j ACCEPT
  iptables -D FORWARD -i "$AP_IFACE" -o "$INTERNET_IFACE" -j ACCEPT

  /etc/init.d/dnsmasq stop
  /etc/init.d/hostapd stop
  /etc/init.d/dbus stop

  kill $MITMDUMP_PID
  kill -TERM "$CHILD" 2> /dev/null
  
  echo "received shutdown signal, exiting."
}

# spoof MAC address
if [ "$MAC" != "unchanged" ] ; then
  ifconfig "$AP_IFACE" down
  if [ "$MAC" == "random" ] ; then
    echo "using random MAC address"
    macchanger -A "$AP_IFACE" 
  else
    echo "setting MAC address to $MAC"
    macchanger --mac "$MAC" "$AP_IFACE"
  fi
  if [ ! $? ] ; then
    echo "Failed to change MAC address, aborting."
    exit 1
  fi
  ifconfig "$AP_IFACE" up
fi 

ifconfig "$AP_IFACE" 192.168.42.1/24

# configure WPA password if provided
if [ ! -z "$PASSWORD" ]; then

  # password length check
  if [ ! ${#PASSWORD} -ge 8 ] && [ ${#PASSWORD} -le 63 ]; then
    echo "PASSWORD must be between 8 and 63 characters"
    echo "password '$PASSWORD' has length: ${#PASSWORD}, exiting."
    exit 1
  fi

  # uncomment WPA2 auth stuff in hostapd.conf
  # replace the password with $PASSWORD
  sed -i 's/#//' /etc/hostapd/hostapd.conf
  sed -i "s/wpa_passphrase=.*/wpa_passphrase=$PASSWORD/g" /etc/hostapd/hostapd.conf
fi

sed -i "s/^ssid=.*/ssid=$SSID/g" /etc/hostapd/hostapd.conf
sed -i "s/interface=.*/interface=$AP_IFACE/g" /etc/hostapd/hostapd.conf
sed -i "s/interface=.*/interface=$AP_IFACE/g" /etc/dnsmasq.conf

/etc/init.d/dbus start
/etc/init.d/dnsmasq start
/etc/init.d/hostapd start

echo 1 > /proc/sys/net/ipv4/ip_forward

# iptables entries to setup AP network
# -C checks if rule exists, -A adds, and -D deletes
iptables -t nat -C POSTROUTING -o "$INTERNET_IFACE" -j MASQUERADE
if [ ! $? -eq 0 ] ; then
    iptables -t nat -A POSTROUTING -o "$INTERNET_IFACE" -j MASQUERADE
fi
iptables -C FORWARD -i "$INTERNET_IFACE" -o "$AP_IFACE" -m state --state RELATED,ESTABLISHED -j ACCEPT 
if [ ! $? -eq 0 ] ; then
    iptables -A FORWARD -i "$INTERNET_IFACE" -o "$AP_IFACE" -m state --state RELATED,ESTABLISHED -j ACCEPT 
fi
iptables -C FORWARD -i "$AP_IFACE" -o "$INTERNET_IFACE" -j ACCEPT
if [ ! $? -eq 0 ] ; then
    iptables -A FORWARD -i "$AP_IFACE" -o "$INTERNET_IFACE" -j ACCEPT
fi

# setup handlers
trap term_handler SIGTERM
trap term_handler SIGKILL

# wait forever
sleep infinity &
CHILD=$!
wait "$CHILD"
