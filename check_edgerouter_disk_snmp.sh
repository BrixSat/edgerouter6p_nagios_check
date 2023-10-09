#!/bin/bash

#
# Author    BrixSat
# Date:     10/10/2023
# Version:  1.0
#

if [ $# -ne 4 ]
then
	echo "Missing arguments!"
	echo "$0 'router_ip' 'snmp_community' 'warning%' 'critical%'"
	exit 2
fi

# Define SNMP parameters
HOST="${1}"
COMMUNITY="${2}"
WARNING_THRESHOLD=$3
CRITICAL_THRESHOLD=$4

OID_QUERY=".1.3.6.1.2.1.25.2.3.1.3" # SNMP OID for hrStorageDescr (Description)
TOTAL_OID=".1.3.6.1.2.1.25.2.3.1.5" # SNMP OID for hrStorageSize (Total Disk Size)
USED_OID=".1.3.6.1.2.1.25.2.3.1.6"  # SNMP OID for hrStorageUsed (Used Disk Size)

# Function to get the correct OID for a given description
get_oid_for_description() {
  snmpwalk -v2c -c "$COMMUNITY" "$HOST" "$OID_QUERY" | grep "\"$1\"" | awk '{print $1}' | grep -o '\.[0-9]*$' | cut -c 2-
}

# List of directories to monitor
DIRECTORIES=(
  "/root.dev"
  "/var/log"
  "Physical memory"
  "Virtual memory"
  "Memory buffers"
  "/dev/shm"
  "/tmp"
 "/opt/vyatta/config"
)

#  "Cached memory"
#  "Shared memory"

# Initialize arrays to store results
STATUS=()
PERFORMANCE=()

# Iterate through directories and check disk space usage
for DIRECTORY in "${DIRECTORIES[@]}"; do
  OID=$(get_oid_for_description "$DIRECTORY")
  # Get total and used disk space in bytes
  TOTAL_BYTES=$(snmpwalk -v2c -c "$COMMUNITY" "$HOST" "$TOTAL_OID.$OID" | awk '{print $4}')
  USED_BYTES=$(snmpwalk -v2c -c "$COMMUNITY" "$HOST" "$USED_OID.$OID" | awk '{print $4}')

  # Calculate the percentage of used disk space
  PERCENT_USED=$(echo "scale=2; ($USED_BYTES / $TOTAL_BYTES) * 100" | bc -l)

  # Check disk usage against thresholds and generate Nagios output
  if (( $(echo "$PERCENT_USED >= $CRITICAL_THRESHOLD" | bc -l) )); then
    STATUS+=("CRITICAL - Disk Usage ($DIRECTORY): ${PERCENT_USED}%")
  elif (( $(echo "$PERCENT_USED >= $WARNING_THRESHOLD" | bc -l) )); then
    STATUS+=("WARNING - Disk Usage ($DIRECTORY): ${PERCENT_USED}%")
  else
    STATUS+=("OK - Disk Usage ($DIRECTORY): ${PERCENT_USED}%")
  fi
  PERFORMANCE+=("$DIRECTORY=${PERCENT_USED}%;${WARNING_THRESHOLD};${CRITICAL_THRESHOLD};0;100")


done

# Check if any directory exceeded thresholds
for stat in "${STATUS[@]}"; do
  if [[ $stat == *"CRITICAL"* ]]; then
    echo "$stat | ${PERFORMANCE[@]}"
    exit 2
  elif [[ $stat == *"WARNING"* ]]; then
    echo "$stat | ${PERFORMANCE[@]}"
    exit 1
  fi
done

# If all directories are within thresholds, report OK
echo "OK - All Disk Usages are within thresholds | ${PERFORMANCE[@]}"

exit 0
