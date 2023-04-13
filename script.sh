#!/bin/bash
echo "-------------------------------------------------------------"

# Set iDRAC IP address
iDRAC=$1

# Set iDRAC username and password
usr=$2
pw=$3
echo "iDRAC IP: $iDRAC Username: $usr"

# Check if Nvidia drivers are installed
# TODO - handle multiple GPUs
if command -v nvidia-smi &>/dev/null; then
    echo -e "\nFound Nvidia GPUs:"
    nvidia-smi --list-gpus

    # If Nvidia GPUs are present and persistence mode is disabled, enable persistence mode
    if [[ $(nvidia-smi --query-gpu="persistence_mode" --format=csv,noheader) == "Disabled" ]]; then
        nvidia-smi --persistence-mode=1
    fi

    # Get the temperature of the highest temperature Nvidia GPU
    gpu_temp=$(nvidia-smi --query-gpu="temperature.gpu" --format=csv,noheader) || gpu_temp=0
    highest_device=$(nvidia-smi --list-gpus | grep -oP 'GPU \d: \K.*(?= \(UUID:)')
else
    # If Nvidia drivers are not installed, set GPU temperature to 0
    gpu_temp=0
fi

# Set highest temperature to GPU temperature
echo -e "\n$highest_device: $gpu_temp"
highest_temp=$gpu_temp

# Get temperature data and loop through lines
temperature=$(ipmitool -I lanplus -H "$iDRAC" -U "$usr" -P "$pw" sdr type temperature)
while read line; do
    # Extract name, hex value, and temperature
    device=$(echo $line | awk -F "|" '{print $1}' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    hex=$(echo $line | awk -F "|" '{print $2}' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    temp=$(echo $line | grep -oE '[[:digit:]]+ degrees C$' | cut -d' ' -f1)
    
    # Rename CPU temperature sensor
    shopt -s nocasematch
    if [[ "$device" == "temp" ]]; then device="CPU"; fi
    echo "$device: $temp"

    # Track highest temperature
    if [[ $temp > $highest_temp ]]; then
        highest_temp=$temp
        highest_device=$device
    fi
done < <(echo "$temperature")
echo -e "\nHighest temp: $highest_temp for $highest_device"

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
