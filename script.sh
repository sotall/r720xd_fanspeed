#!/bin/bash

# check for driver
command -v nvidia-smi &> /dev/null || { echo >&2 "nvidia driver is not installed you will need to install this from community applications ... exiting."; exit 1; }
echo "Nvidia drivers are installed"
echo
echo "I can see these Nvidia gpus in your server"
echo
nvidia-smi --list-gpus 
echo
echo "-------------------------------------------------------------"

# set persistence mode for gpus ( When persistence mode is enabled the NVIDIA driver remains loaded even when no active processes, 
# stops modules being unloaded therefore stops settings changing when modules are reloaded
echo "Checking if persistence mode is enabled"
persistence_mode=$(nvidia-smi --query-gpu="persistence_mode" --format=csv,noheader);
if [ $persistence_mode = "Disabled" ]; then
    echo "Enabling persistence mode"
    nvidia-smi --persistence-mode=1
else
    echo "Persistence mode is already enabled"
fi
echo
echo "-------------------------------------------------------------"

# set iDRAC IP
iDRAC=$1

# set iDRAC Credentials
usr=$2
pw=$3

# query gpu temperature
gpu_temp=$(nvidia-smi --query-gpu="temperature.gpu" --format=csv,noheader);

# query cpu temperature
temperature=$(ipmitool -I lanplus -H $iDRAC -U $usr -P $pw sensor reading "Temp")
cpu_temp=${temperature: -2} # get last 2 characters of string

echo "CPU Temp: $cpu_temp"
echo "GPU Temp: $gpu_temp"

# set fan speed
# 00 - 0%  - 1800  RPM
# 05 - 5%  - 2400  RPM
# 0a - 10% - 3240  RPM
# 0f - 15% - 4080  RPM
# 14 - 20% - 4800  RPM
# 19 - 25% - 5640  RPM
# 1e - 30% - 6480  RPM
# 23 - 35% - 7200  RPM
# 28 - 40% - 8040  RPM
# 2d - 45% - 8760  RPM
# 32 - 50% - 9600  RPM
# 3c - 60% - 11520 RPM
# 46 - 70% - 13440 RPM
# 50 - 80% - 15360 RPM
# 64 - 100% - 19200 RPM

# enables fan control via ipmitool
ipmitool -I lanplus -H $iDRAC -U $usr -P $pw raw 0x30 0x30 0x01 0x00

# change fan speed hex value depending on temperature (0x00 = 0%, 0x64 = 100%)
if [ $cpu_temp -ge 80 ]; then
    echo "Setting fan speed to 100%"
    ipmitool -I lanplus -H $iDRAC -U $usr -P $pw raw 0x30 0x30 0x02 0xff 0x64
elif [ $cpu_temp -ge 70 ]; then
    echo "Setting fan speed to 80%"
    ipmitool -I lanplus -H $iDRAC -U $usr -P $pw raw 0x30 0x30 0x02 0xff 0x50
elif [ $cpu_temp -ge 60 ]; then
    echo "Setting fan speed to 60%"
    ipmitool -I lanplus -H $iDRAC -U $usr -P $pw raw 0x30 0x30 0x02 0xff 0x3c
elif [ $cpu_temp -ge 50 ]; then
    echo "Setting fan speed to 40%"
    ipmitool -I lanplus -H $iDRAC -U $usr -P $pw raw 0x30 0x30 0x02 0xff 0x28
elif [ $cpu_temp -ge 40 ]; then
    echo "Setting fan speed to 20%"
    ipmitool -I lanplus -H $iDRAC -U $usr -P $pw raw 0x30 0x30 0x02 0xff 0x14
else
    echo "Setting fan speed to 0%"
    ipmitool -I lanplus -H $iDRAC -U $usr -P $pw raw 0x30 0x30 0x02 0xff 0x00
fi


