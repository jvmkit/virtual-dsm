#!/usr/bin/env bash
set -u

[ ! -f "/run/qemu.pid" ] && echo "QEMU not running yet.." && exit 0

# Retrieve IP from guest for Docker healthcheck
RESPONSE=$(curl -s -m 6 -S http://127.0.0.1:2210/read?command=10 2>&1)

if [[ ! "${RESPONSE}" =~ "\"success\"" ]] ; then
  echo "Failed to connect to guest: $RESPONSE" && exit 1
fi


# Retrieve the HTTP port number

if [[ ! "${RESPONSE}" =~ "\"http_port\"" ]] ; then
  echo "Failed to parse response from guest: $RESPONSE" && exit 1
fi


rest=${RESPONSE#*http_port}
rest=${rest#*:}
rest=${rest%%,*}
PORT=${rest%%\"*}

if [ -z "${PORT}" ]; then
  echo "Guest has not set a portnumber yet.." && exit 1
fi


# Retrieve the IP address

if [[ ! "${RESPONSE}" =~ "eth0" ]] ; then
  echo "Failed to parse response from guest: $RESPONSE" && exit 1
fi


rest=${RESPONSE#*eth0}
rest=${rest#*ip}
rest=${rest#*:}
rest=${rest#*\"}
IP=${rest%%\"*}

if [ -z "${IP}" ]; then
  echo "Guest has not received an IP yet.." && exit 1
fi


if [[ "$IP" != "20.20"* ]] && [[ ! -f "/run/vlan.pid" ]] ; then

  echo $$ > "/run/vlan.pid"

  # Create a macvlan network to reach the VM guest
  { ip link add link eth0 dsm_vlan type macvlan mode bridge ; rc=$?; } || :

  (( rc != 0 )) && echo "Cannot create macvlan interface." && exit 1

  HOST_IP=$(ip address show dev eth0 | grep inet | awk '/inet / { print $2 }' | cut -f1 -d/)

  #ip address add "${HOST_IP}" dev dsm_vlan
  #ip link set dev dsm_vlan up

  #ip route flush dev dsm_vlan

  #ip route add "${IP}"/32 dev dsm_vlan metric 0
  echo "Finished.."
fi

if ! curl -m 3 -ILfSs "http://${IP}:${PORT}/" > /dev/null; then
  echo "Failed to reach ${IP}:${PORT}"
  exit 1
fi

echo "Healthcheck OK ($IP)"
exit 0
