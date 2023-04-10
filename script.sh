#!/bin/bash

echo "-------------------------------------------------------------"
# set iDRAC IP
iDRAC=$1
echo "iDRAC IP: $iDRAC"

# set iDRAC Credentials
usr=$2
pw=$3
echo "iDRAC Username: $usr"

# check for nVidia driver
if command -v nvidia-smi &> /dev/null; then
  gpu_temp=$(nvidia-smi --query-gpu="temperature.gpu" --format=csv,noheader)
  echo -e "\nNvidia drivers are installed\nI can see these Nvidia gpus in your server\n"
  nvidia-smi --list-gpus 

  # set persistence mode for gpus
  echo "Checking if persistence mode is enabled"
  if [[ $(nvidia-smi --query-gpu="persistence_mode" --format=csv,noheader) = "Disabled" ]]; then
    echo "Enabling persistence mode"
    nvidia-smi --persistence-mode=1
  else
    echo "Persistence mode is already enabled"
  fi

else
  gpu_temp=0 # Set GPU temp to 0 if NVIDIA driver is not installed
fi

# query temperatures
temp=$(ipmitool -I lanplus -H $iDRAC -U $usr -P $pw sdr type temperature)
cpu1_temp=$(echo "$temp" | grep 0Eh | cut -d \| -f5 | grep -Po '\d\d')
cpu2_temp=$(echo "$temp" | grep 0Fh | cut -d \| -f5 | grep -Po '\d\d')
exhaust_temp=$(echo "$temp" | grep 01h | cut -d \| -f5 | grep -Po '\d\d')
gpu_temp=$(nvidia-smi --query-gpu="temperature.gpu" --format=csv,noheader)

echo "CPU1 Temp: $cpu1_temp"
echo "CPU2 Temp: $cpu2_temp"
echo "Exhaust Temp: $exhaust_temp"
echo "GPU Temp: $gpu_temp"

# get highest cpu and gpu temps
cpu_temp=$((cpu1_temp > cpu2_temp ? cpu1_temp : cpu2_temp))
echo "User highest CPU temp"
echo "CPU Temp: $cpu_temp"

gpu_temp=$(nvidia-smi --query-gpu="temperature.gpu" --format=csv,noheader)
echo "GPU Temp: $gpu_temp"

# set fan speed based on highest temperature
declare -A fan_speeds=(
    [100]=19200 [80]=15360 [70]=13440 [60]=11520 [50]=9600 [45]=8760 [40]=8040 [35]=7200 [30]=6480 [25]=5640 [20]=4800 [15]=4080 [10]=3240 [5]=2400
    )
fan_speed=$(for temp in "${!fan_speeds[@]}"; do 
  [[ $cpu_temp -ge $temp || $gpu_temp -ge $temp ]] && echo "${fan_speeds[$temp]}" && break 
done)
echo "Setting fan speed to ${fan_speed:-0} RPM"

# set the fan speed using IPMItool
ipmitool -I lanplus -H $iDRAC -U $usr -P $pw raw 0x30 0x30 0x02 0xff "${fan_speed:-0}"
