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
LOAD_1MIN_OID=".1.3.6.1.4.1.2021.10.1.3.1"    # SNMP OID for load 1-minute
LOAD_5MIN_OID=".1.3.6.1.4.1.2021.10.1.3.2"    # SNMP OID for load 5-minute
LOAD_15MIN_OID=".1.3.6.1.4.1.2021.10.1.3.3"   # SNMP OID for load 15-minute

# Function to get the load average for a given OID
get_load_average() {
  local oid="$1"
  local value=$(snmpget -v2c -c "$COMMUNITY" -OQv "$HOST" "$oid")
  echo "$value"
}

# Get load average values
LOAD_1MIN=$(get_load_average "$LOAD_1MIN_OID")
LOAD_5MIN=$(get_load_average "$LOAD_5MIN_OID")
LOAD_15MIN=$(get_load_average "$LOAD_15MIN_OID")

# Define warning and critical thresholds (adjust as needed)
WARNING_THRESHOLD_1MIN=2.0
CRITICAL_THRESHOLD_1MIN=4.0
WARNING_THRESHOLD_5MIN=2.0
CRITICAL_THRESHOLD_5MIN=4.0
WARNING_THRESHOLD_15MIN=2.0
CRITICAL_THRESHOLD_15MIN=4.0
PERFORMANCE_DATA=$(echo "Load1=${LOAD_1MIN};${WARNING_THRESHOLD_1MIN};${CRITICAL_THRESHOLD_1MIN};;; Load5=${LOAD_5MIN};${WARNING_THRESHOLD_5MIN};${CRITICAL_THRESHOLD_5MIN};;; Load15=${LOAD_15MIN};${WARNING_THRESHOLD_15MIN};${CRITICAL_THRESHOLD_15MIN};;;" | sed 's/"//g')

# Check load average values against thresholds and generate Nagios output
if (( $(awk 'BEGIN { print "'"$LOAD_1MIN"'" >= "'"$CRITICAL_THRESHOLD_1MIN"'" }') )); then
  echo "CRITICAL - Load Average (1-minute): ${LOAD_1MIN} | ${PERFORMANCE_DATA}"
  exit 2
elif (( $(awk 'BEGIN { print "'"$LOAD_1MIN"'" >= "'"$WARNING_THRESHOLD_1MIN"'" }') )); then
  echo "WARNING - Load Average (1-minute): ${LOAD_1MIN} | ${PERFORMANCE_DATA}"
  exit 1
elif (( $(awk 'BEGIN { print "'"$LOAD_5MIN"'" >= "'"$CRITICAL_THRESHOLD_5MIN"'" }') )); then
  echo "CRITICAL - Load Average (5-minute): ${LOAD_5MIN} | ${PERFORMANCE_DATA}"
  exit 2
elif (( $(awk 'BEGIN { print "'"$LOAD_5MIN"'" >= "'"$WARNING_THRESHOLD_5MIN"'" }') )); then
  echo "WARNING - Load Average (5-minute): ${LOAD_5MIN} | ${PERFORMANCE_DATA}"
  exit 1
elif (( $(awk 'BEGIN { print "'"$LOAD_15MIN"'" >= "'"$CRITICAL_THRESHOLD_15MIN"'" }') )); then
  echo "CRITICAL - Load Average (15-minute): ${LOAD_15MIN} | ${PERFORMANCE_DATA}"
  exit 2
elif (( $(awk 'BEGIN { print "'"$LOAD_15MIN"'" >= "'"$WARNING_THRESHOLD_15MIN"'" }') )); then
  echo "WARNING - Load Average (15-minute): ${LOAD_15MIN} | ${PERFORMANCE_DATA}"
  exit 1
else
  echo "OK - Load Average (1-minute): ${LOAD_1MIN}, (5-minute): ${LOAD_5MIN}, (15-minute): ${LOAD_15MIN} | ${PERFORMANCE_DATA}"
  exit 0
fi
