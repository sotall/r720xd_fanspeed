#!/bin/bash

echo "-------------------------------------------------------------"
# set iDRAC IP
iDRAC=$1
echo "iDRAC IP: $iDRAC"

# set iDRAC Credentials
usr=$2
pw=$3
echo "iDRAC Username: $usr"

# check for driver
command -v nvidia-smi &> /dev/null || { echo >&2 "nvidia driver is not installed you will need to install this from community applications ... exiting."; exit 1; }
echo
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

# query gpu temperature
gpu_temp=$(nvidia-smi --query-gpu="temperature.gpu" --format=csv,noheader);

# query cpu temperature
cpu1_temp=$(ipmitool -I lanplus -H  $iDRAC -U $usr -P $pw sdr type temperature | grep 0Eh | cut -d \| -f5 | grep -P -o '\d\d')
cpu2_temp=$(ipmitool -I lanplus -H  $iDRAC -U $usr -P $pw sdr type temperature | grep 0Fh | cut -d \| -f5 | grep -P -o '\d\d')

# query exhaust temperature
exhaust_temp=$(ipmitool -I lanplus -H  $iDRAC -U $usr -P $pw sdr type temperature | grep 01h | cut -d \| -f5 | grep -P -o '\d\d')

echo "CPU1 Temp: $cpu1_temp"
echo "CPU2 Temp: $cpu2_temp"
echo "Exhaust Temp: $exhaust_temp"
echo "GPU Temp: $gpu_temp"

# get highest cpu temp
if [ $cpu1_temp -gt $cpu2_temp ]; then
    cpu_temp=$cpu1_temp
else
    cpu_temp=$cpu2_temp
fi
echo "User highest CPU temp"
echo "CPU Temp: $cpu_temp"

# E5-2680 v2
# temp max = 82c

# Tesla P4
# temp max = 90c
# GPU Shutdown Temp: 94 C
# GPU Slowdown Temp: 91 C

# set fan speed
fan_100_19200rpm="0x30 0x30 0x02 0xff 0x64" # 64 - 100% - 19200 RPM
fan_080_15360rpm="0x30 0x30 0x02 0xff 0x50" # 50 - 80% - 15360 RPM
fan_070_13440rpm="0x30 0x30 0x02 0xff 0x46" # 46 - 70% - 13440 RPM
fan_060_11520rpm="0x30 0x30 0x02 0xff 0x3c" # 3c - 60% - 11520 RPM
fan_050_09600rpm="0x30 0x30 0x02 0xff 0x32" # 32 - 50% - 9600  RPM
fan_045_08760rpm="0x30 0x30 0x02 0xff 0x2d" # 2d - 45% - 8760  RPM
fan_040_08040rpm="0x30 0x30 0x02 0xff 0x28" # 28 - 40% - 8040  RPM
fan_035_07200rpm="0x30 0x30 0x02 0xff 0x23" # 23 - 35% - 7200  RPM
fan_030_06480rpm="0x30 0x30 0x02 0xff 0x1e" # 1e - 30% - 6480  RPM
fan_025_05640rpm="0x30 0x30 0x02 0xff 0x19" # 19 - 25% - 5640  RPM
fan_020_04800rpm="0x30 0x30 0x02 0xff 0x14" # 14 - 20% - 4800  RPM
fan_015_04080rpm="0x30 0x30 0x02 0xff 0x0f" # 0f - 15% - 4080  RPM
fan_010_03240rpm="0x30 0x30 0x02 0xff 0x0a" # 0a - 10% - 3240  RPM
fan_005_02400rpm="0x30 0x30 0x02 0xff 0x05" # 05 - 5%  - 2400  RPM
fan_000_01800rpm="0x30 0x30 0x02 0xff 0x00" # 00 - 0%  - 1800  RPM

# enables fan control via ipmitool
ipmitool -I lanplus -H $iDRAC -U $usr -P $pw raw 0x30 0x30 0x01 0x00

# set fan speed based on cpu temp and gpu temp
if [ $cpu_temp -gt 75 ] || [ $gpu_temp -gt 75 ]; then
    echo "Setting fan speed to 70%"
    ipmitool -I lanplus -H $iDRAC -U $usr -P $pw raw $fan_070_13440rpm
elif [ $cpu_temp -gt 70 ] || [ $gpu_temp -gt 70 ]; then
    echo "Setting fan speed to 60%"
    ipmitool -I lanplus -H $iDRAC -U $usr -P $pw raw $fan_060_11520rpm
elif [ $cpu_temp -gt 65 ] || [ $gpu_temp -gt 65 ]; then
    echo "Setting fan speed to 50%"
    ipmitool -I lanplus -H $iDRAC -U $usr -P $pw raw $fan_050_09600rpm
elif [ $cpu_temp -gt 60 ] || [ $gpu_temp -gt 60 ]; then
    echo "Setting fan speed to 45%"
    ipmitool -I lanplus -H $iDRAC -U $usr -P $pw raw $fan_045_08760rpm
elif [ $cpu_temp -gt 55 ] || [ $gpu_temp -gt 55 ]; then
    echo "Setting fan speed to 40%"
    ipmitool -I lanplus -H $iDRAC -U $usr -P $pw raw $fan_040_08040rpm
elif [ $cpu_temp -gt 50 ] || [ $gpu_temp -gt 50 ]; then
    echo "Setting fan speed to 35%"
    ipmitool -I lanplus -H $iDRAC -U $usr -P $pw raw $fan_035_07200rpm
elif [ $cpu_temp -gt 45 ] || [ $gpu_temp -gt 45 ]; then
    echo "Setting fan speed to 30%"
    ipmitool -I lanplus -H $iDRAC -U $usr -P $pw raw $fan_030_06480rpm
elif [ $cpu_temp -gt 40 ] || [ $gpu_temp -gt 40 ]; then
    echo "Setting fan speed to 25%"
    ipmitool -I lanplus -H $iDRAC -U $usr -P $pw raw $fan_025_05640rpm
elif [ $cpu_temp -gt 35 ] || [ $gpu_temp -gt 35 ]; then
    echo "Setting fan speed to 20%"
    ipmitool -I lanplus -H $iDRAC -U $usr -P $pw raw $fan_020_04800rpm
elif [ $cpu_temp -gt 30 ] || [ $gpu_temp -gt 30 ]; then
    echo "Setting fan speed to 15%"
    ipmitool -I lanplus -H $iDRAC -U $usr -P $pw raw $fan_015_04080rpm
elif [ $cpu_temp -gt 25 ] || [ $gpu_temp -gt 25 ]; then
    echo "Setting fan speed to 10%"
    ipmitool -I lanplus -H $iDRAC -U $usr -P $pw raw $fan_010_03240rpm
elif [ $cpu_temp -gt 20 ] || [ $gpu_temp -gt 20 ]; then
    echo "Setting fan speed to 5%"
    ipmitool -I lanplus -H $iDRAC -U $usr -P $pw raw $fan_005_02400rpm
else
    echo "Setting fan speed to 0%"
    ipmitool -I lanplus -H $iDRAC -U $usr -P $pw raw $fan_000_01800rpm
fi
