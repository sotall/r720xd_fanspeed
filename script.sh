#!/bin/bash

# This script sets the fan speed of an iDRAC-enabled server based on the highest temperature
# of the system. It also checks if Nvidia drivers are installed and if Nvidia GPUs are
# present in the system.

echo "-------------------------------------------------------------"

# Set iDRAC IP address
iDRAC=$1
echo "iDRAC IP: $iDRAC"

# Set iDRAC username and password
usr=$2
pw=$3
echo "iDRAC Username: $usr"

# Check if Nvidia drivers are installed
if command -v nvidia-smi &>/dev/null; then
    echo "Found Nvidia GPUs:"
    nvidia-smi --list-gpus

    # If Nvidia GPUs are present and persistence mode is disabled, enable persistence mode
    if [[ $(nvidia-smi --query-gpu="persistence_mode" --format=csv,noheader) == "Disabled" ]]; then
        nvidia-smi --persistence-mode=1
    fi

    # Get the temperature of the highest temperature Nvidia GPU
    gpu_temp=$(nvidia-smi --query-gpu="temperature.gpu" --format=csv,noheader) || gpu_temp=0
else
    # If Nvidia drivers are not installed, set GPU temperature to 0
    gpu_temp=0
fi

# Set the highest temperature to the temperature of the highest temperature sensor
highest_temp=$gpu_temp
while read -r line; do
    temp=$(echo "$line" | grep -oE '[[:digit:]]+ degrees C$' | cut -d' ' -f1)
    ((temp > highest_temp)) && highest_temp=$temp
done < <(ipmitool -I lanplus -H "$iDRAC" -U "$usr" -P "$pw" sdr type temperature | grep -oE '[[:digit:]]{1,2}h')

echo -e "\nHighest temp: $highest_temp"

# Set fan speed based on temperature
declare -A fan_speeds=(
    [100]=0x64 [80]=0x50 [70]=0x46 [60]=0x3c [50]=0x32 [45]=0x2d [40]=0x28 [35]=0x23 [30]=0x1e [25]=0x19 [20]=0x14 [15]=0x0f [10]=0x0a [5]=0x05 [0]=0x00
)

# Loop through the fan_speeds array and set the fan speed based on the highest temperature
for temp in $(echo "${!fan_speeds[@]}" | tr ' ' '\n' | sort -n); do
    dec_value=$(printf "%d" ${fan_speeds[$temp]})

    # Convert fan speed from hexadecimal to RPM
    rpm=$(echo "172.8 * $dec_value + 1800 + 0.5" | bc)
    rpm=$(printf "%.0f" $rpm)

    if (($highest_temp >= $temp)); then
        fan_percent=${fan_speeds[$temp]}
        last_rpm=$rpm
    else
        break
    fi
done

echo -e "\nSetting fan speed to around ${last_rpm} RPM"

# Set fan speed
ipmitool -I lanplus -H "$iDRAC" -U "$usr" -P "$pw" raw 0x30 0x30 0x02 0xff "${fan_percent:-0x19}"
