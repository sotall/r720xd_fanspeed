#!/bin/bash

# This script connects to an iDRAC and checks the temperature of the CPUs
# The highest CPU temperature is returned
# The script is called by the script check_idrac_temp.sh
# The script is called with the IP address, username, and password of the iDRAC
# The script is called as follows:
# get_ipmi_temperature 

function get_ipmi_temperature {
    iDRAC=$1
    usr=$2
    pw=$3

    temperature=$(idrac_cpu_temp)

    highest_temp=0
    highest_device=""

    while read line; do
        device=$(echo $line | awk -F "|" '{print $1}' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        hex=$(echo $line | awk -F "|" '{print $2}' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        temp=$(echo $line | grep -oE '[[:digit:]]+ degrees C$' | cut -d' ' -f1)

        shopt -s nocasematch
        if [[ "$device" == "temp" ]]; then device="CPU"; fi
        echo "$device: $temp"

        if [[ $temp > $highest_temp ]]; then
            highest_temp=$temp
            highest_device=$device
        fi
    done < <(echo "$temperature")

    echo -e "\nHighest temp: $highest_temp for $highest_device"
}
