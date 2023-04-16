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
    [80]=0x64  # 19200 RPM
    [75]=0x50  # 15360 RPM
    [70]=0x46  # 13440 RPM
    [65]=0x3c  # 11520 RPM
    [60]=0x32  # 9600 RPM
    [55]=0x2d  # 8760 RPM
    [50]=0x28  # 8040 RPM
    [45]=0x23  # 7200 RPM
    [40]=0x1e  # 6480 RPM
    [35]=0x19  # 5640 RPM
    [30]=0x14  # 4800 RPM
    [25]=0x0f  # 4080 RPM
    [20]=0x0a  # 3240 RPM
    [15]=0x05  # 2400 RPM
    [10]=0x00  # 1800 RPM
)

declare -A fan_rpm=(
    [80]=19200
    [75]=15360
    [70]=13440
    [65]=11520
    [60]=9600
    [55]=8760
    [50]=8040
    [45]=7200
    [40]=6480
    [35]=5640
    [30]=4800
    [25]=4080
    [20]=3240
    [15]=2400
    [10]=1800 
)

# Loop through the fan_speeds array and set the fan speed based on the highest temperature
for temp in $(echo "${!fan_speeds[@]}" | tr ' ' '\n' | sort -n); do
    dec_value=$(printf "%d" ${fan_speeds[$temp]})

    if (($highest_temp >= $temp)); then
        fan_speed=${fan_speeds[$temp]}
        last_rpm=${fan_rpm[$temp]}
    else
        break
    fi
done

echo -e "\nSetting fan speed to around ${last_rpm} RPM"

# Set fan speed
ipmitool -I lanplus -H "$iDRAC" -U "$usr" -P "$pw" raw 0x30 0x30 0x02 0xff "${fan_speed:-0x19}"
