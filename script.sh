#!/bin/bash

echo "-------------------------------------------------------------"
# set iDRAC IP
iDRAC=$1
echo "iDRAC IP: $iDRAC"

# set iDRAC Credentials
usr=$2
pw=$3
echo "iDRAC Username: $usr"

if command -v nvidia-smi &>/dev/null; then
    echo -e "\nNvidia drivers are installed\nI can see these Nvidia GPUs in your server\n"
    nvidia-smi --list-gpus

    if [[ $(nvidia-smi --query-gpu="persistence_mode" --format=csv,noheader) == "Disabled" ]]; then
        nvidia-smi --persistence-mode=1
    fi

    gpu_temp=$(nvidia-smi --query-gpu="temperature.gpu" --format=csv,noheader) || gpu_temp=0
else
    gpu_temp=0
fi

highest_temp=$gpu_temp
while read -r line; do
    temp=$(echo "$line" | grep -oE '[[:digit:]]+ degrees C$' | cut -d' ' -f1)
    ((temp > highest_temp)) && highest_temp=$temp
done < <(ipmitool -I lanplus -H "$iDRAC" -U "$usr" -P "$pw" sdr type temperature | grep -oE '[[:digit:]]{1,2}h')

echo -e "\nHighest temp: $highest_temp"

declare -A fan_speeds=(
    [100]=0x64  # 19200 RPM
    [80]=0x50  # 15360 RPM
    [70]=0x46  # 13440 RPM
    [60]=0x3c  # 11520 RPM
    [50]=0x32  # 9600 RPM
    [45]=0x2d  # 8760 RPM
    [40]=0x28  # 8040 RPM
    [35]=0x23  # 7200 RPM
    [30]=0x1e  # 6480 RPM
    [25]=0x19  # 5640 RPM
    [20]=0x14  # 4800 RPM
    [15]=0x0f  # 4080 RPM
    [10]=0x0a  # 3240 RPM
    [5]=0x05  # 2400 RPM
    [0]=0x00  # 1800 RPM 
)
for temp in $(echo "${!fan_speeds[@]}" | tr ' ' '\n' | sort -n); do
    dec_value=$(printf "%d" ${fan_speeds[$temp]})
    rpm=$(echo "172.8 * $dec_value + 1800 + 0.5" | bc)
    rpm=$(printf "%.0f" $rpm)
    last_percent=$fan_percent

    if (($highest_temp >= $temp)); then
        echo -e "\nTemp: $temp"
        echo "Fan speed: ${fan_speeds[$temp]}"
        echo "Highest temp: $highest_temp"
        echo "${temp}% - ${rpm} RPM"
        fan_percent=${fan_speeds[$temp]}
        last_rpm=$rpm
    else
        break
    fi
done

echo -e "\nSetting fan speed to around ${last_rpm} RPM"
ipmitool -I lanplus -H "$iDRAC" -U "$usr" -P "$pw" raw 0x30 0x30 0x02 0xff "${fan_percent:-0x19}"
