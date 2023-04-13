#!/bin/bash

iDRAC=$1                # Replace with the IP address of your iDRAC
usr=$2                  # Replace with your iDRAC username
pw=$3                   # Replace with your iDRAC password
temp_threshold=${4:-40} # Replace with your desired temperature threshold
speed=${5:-0x46}        # Maximum speed
increment=${6:--0x08}   # Speed increment (-5% in hex)

function idrac_set_fan_speed {
    hex_val=$1
    ipmitool -I lanplus -H $iDRAC -U $usr -P $pw raw 0x30 0x30 0x02 0xff "$hex_val"
}

function idrac_get_temp {
    # Optional argument to ipmitool sdr command
    optional=${1:-""}
    # Output of ipmitool sdr command
    temperature=$(ipmitool -I lanplus -H "$iDRAC" -U "$usr" -P "$pw" sdr type temperature $optional)
    echo "$temperature"
}

function idrac_get_temp_by_hex {
    hex_val=$1
    temperature=$(ipmitool -I lanplus -H "$iDRAC" -U "$usr" -P "$pw" sdr type temperature | grep -i "$hex_val")
    device=$(echo "$temperature" | awk -F "|" '{print $1}' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    temp=$(echo "$temperature" | grep -oE '[[:digit:]]+ degrees C$' | cut -d' ' -f1)

    echo "$device: $temp"
}

# Call the function and echo the result
result=$(idrac_get_temp 01h)
echo "$result"

function nvidia_get_gpu_temp {
    # Check if Nvidia drivers are installed
    if command -v nvidia-smi &>/dev/null; then
        echo -e "\nFound Nvidia GPUs:"
        nvidia-smi --list-gpus

        # If Nvidia GPUs are present and persistence mode is disabled, enable persistence mode
        if [[ $(nvidia-smi --query-gpu="persistence_mode" --format=csv,noheader) == "Disabled" ]]; then
            nvidia-smi --persistence-mode=1
        fi

        # Get the temperature of the highest temperature Nvidia GPU
        gpu_temp=$(nvidia-smi --query-gpu="temperature.gpu" --format=csv,noheader) || gpu_temp=0
        gpu_name=$(nvidia-smi --list-gpus | grep -oP 'GPU \d: \K.*(?= \(UUID:)') || gpu_name=""
    else
        # If Nvidia drivers are not installed, set GPU temperature to 0
        gpu_temp=0
        gpu_name=""
    fi

    # return temperature and device name
    echo "$gpu_temp,$gpu_name"
}

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

while true; do
    temp=$(idrac_cpu_temp) # Get ambient temperature
    if [ "$temp" -gt "$temp_threshold" ]; then
        # Lower fan speed until temperature starts to increase
        while true; do
            # Decrease fan speed by 5%
            speed=$((speed - increment))
            if [ "$speed" -lt 0x10 ]; then
                speed=0x10 # Minimum fan speed
            fi
            idrac_set_fan_speed "$speed" # Adjust fan speed
            sleep 30                     # Wait for 30 seconds before checking temperature again
            new_temp=$(idrac_cpu_temp)   # Get ambient temperature
            if [ "$new_temp" -gt "$temp" ]; then
                break # Temperature has started to increase, exit loop
            fi
            temp=$new_temp # Update temperature variable
        done
        # Gradually increase fan speed while keeping temperature low
        while true; do
            # Increase fan speed by 5%
            speed=$((speed + increment))
            if [ "$speed" -gt 0xff ]; then
                speed=0xff # Maximum fan speed
            fi
            idrac_set_fan_speed "$speed" # Adjust fan speed
            sleep 30                     # Wait for 30 seconds before checking temperature again
            new_temp=$(idrac_cpu_temp)   # Get ambient temperature
            if [ "$new_temp" -le "$temp" ]; then
                break # Temperature has decreased, exit loop
            fi
            temp=$new_temp # Update temperature variable
        done
    fi
    idrac_set_fan_speed "$speed" # Adjust fan speed
    sleep 30                     # Wait for 30 seconds before checking temperature again
done
