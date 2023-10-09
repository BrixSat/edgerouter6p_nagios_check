#!/bin/bash

#
# Author    BrixSat
# Date:     10/10/2023
# Version:  1.0
#

if [ $# -ne 2 ]
then
        echo "Missing arguments!"
        echo "$0 'router_ip' 'snmp_community'"
        exit 2
fi


# Define SNMP parameters
HOST="${1}"
COMMUNITY="${2}"
IF_NAME_OID=".1.3.6.1.2.1.31.1.1.1.1"  # SNMP OID for interface names
IF_IN_OID=".1.3.6.1.2.1.2.2.1.10"    # SNMP OID for interface input octets (bytes)
IF_OUT_OID=".1.3.6.1.2.1.2.2.1.16"   # SNMP OID for interface output octets (bytes)
INTERFACE_INTERVAL=5  # Interval in seconds for bandwidth calculation

# Initialize arrays to store interface information
interfaces=()

# Function to check if an interface is operational
is_interface_operational() {
  local index="$1"
  local status_oid=".1.3.6.1.2.1.2.2.1.8.$index"  # SNMP OID for interface operational status
  local status=$(snmpget -v2c -c "$COMMUNITY" -OQv "$HOST" "$status_oid")
  if [ "$status" = "1" ]; then
    return 0  # Interface is up
  else
    return 1  # Interface is down
  fi
}

# Function to calculate bandwidth in Mbps
calculate_bandwidth() {
  local index="$1"
  local in_oid="$IF_IN_OID.$index"  # SNMP OID for interface input octets
  local out_oid="$IF_OUT_OID.$index"  # SNMP OID for interface output octets
  local in_bytes_initial=$(snmpget -v2c -c "$COMMUNITY" -OQv "$HOST" "$in_oid")
  local out_bytes_initial=$(snmpget -v2c -c "$COMMUNITY" -OQv "$HOST" "$out_oid")

  sleep "$INTERFACE_INTERVAL"
  local in_bytes_final=$(snmpget -v2c -c "$COMMUNITY" -OQv "$HOST" "$in_oid")
  local out_bytes_final=$(snmpget -v2c -c "$COMMUNITY" -OQv "$HOST" "$out_oid")
  local in_bytes_diff=$((in_bytes_final - in_bytes_initial))
  local out_bytes_diff=$((out_bytes_final - out_bytes_initial))
  local in_mbps=$(echo "scale=2; $in_bytes_diff / $INTERFACE_INTERVAL / 125000" | bc)
  local out_mbps=$(echo "scale=2; $out_bytes_diff / $INTERFACE_INTERVAL / 125000" | bc)
  local interface_name=$(snmpget -v2c -c "$COMMUNITY" -OQv "$HOST" "$IF_NAME_OID.$index")

  # Nagios plugin format
  ifname=$(echo ${interface_name} | sed 's/"//g')
  if is_interface_operational "$index"; then
    echo "${ifname}_RX=${in_mbps}Mbps;;;;; ${ifname}_TX=${out_mbps}Mbps;;;;;" > /tmp/.${ifname}.txt
  else
    echo "${ifname}_RX=0Mbps;;;;; ${ifname}_TX=0Mbps;;;;;" > /tmp/.${ifname}.txt
  fi
}

# Get the list of interface indexes using IF-MIB::ifName
interface_indexes=$(snmpwalk -v2c -c "$COMMUNITY" -OQn "$HOST" "$IF_NAME_OID" | sed 's/.1.3.6.1.2.1.31.1.1.1.1.//g' | awk '{print $1}')

# Iterate through all interfaces and calculate bandwidth in parallel
for index in $interface_indexes; do
  calculate_bandwidth "$index" &
done

# Wait for all background processes to finish
wait

for index in $interface_indexes; do
    interface_name=$(snmpget -v2c -c "$COMMUNITY" -OQv "$HOST" "$IF_NAME_OID.$index")
    ifname=$(echo ${interface_name} | sed 's/"//g')
    interfaces+=$(cat "/tmp/.${ifname}.txt")
done


# Check the number of interfaces found
if [ ${#interfaces[@]} -eq 0 ]; then
  echo "UNKNOWN - No interfaces found"
  exit 3
fi

# Final output with performance data
echo "OK - All Interfaces | ${interfaces[@]}" | tr '\n' ' '
