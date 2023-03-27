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
persistence_mode=$(nvidia-smi --query-gpu="persistence_mode" --format=csv,noheader);
if [ $persistence_mode = "Disabled" ]; then
    echo "Enabling persistence mode"
    nvidia-smi --persistence-mode=1
else
    echo "Persistence mode is already enabled"
fi
echo
echo "-------------------------------------------------------------"


nvidia-smi --persistence-mode=1

#query gpu temperature
gpu_temp=$(nvidia-smi --query-gpu="temperature.gpu" --format=csv,noheader);

# set iDRAC IP
iDRAC=$1

# set iDRAC Credentials
usr=$2
pw=$3

# enables fan control via ipmitool
ipmitool -I lanplus -H $iDRAC -U $usr -P $pw raw 0x30 0x30 0x01 0x00

# capture temp
temperature=$(ipmitool -I lanplus -H $iDRAC -U $usr -P $pw sensor reading "Temp")
cpu_temp=${temperature: -2} # get last 2 characters of string

echo "CPU Temp: $cpu_temp"
echo "GPU Temp: $gpu_temp"



# # 10% fans at 45C or less = 3240 RPM
# if [[ $current_temp -le 35 ]] || [[ $gpu_temp > 36 ]]
# then
# ipmitool -I lanplus -H $iDRAC -U $usr -P $pw raw 0x30 0x30 0x02 0xff 0x0a
# exit 1
# fi

# # 15% fans at 50C or less = 4080 RPM
# if [ $current_temp -le 40 ]
# then
# ipmitool -I lanplus -H $iDRAC -U $usr -P $pw raw 0x30 0x30 0x02 0xff 0x0f
# exit 1
# fi

# # 20% fans at 55C or less = 4800 RPM
# if [ $current_temp -le 45 ]
# then
# ipmitool -I lanplus -H $iDRAC -U $usr -P $pw raw 0x30 0x30 0x02 0xff 0x14
# exit 1
# fi

# # 30% fans between 55C, 65C = 6480 RPM
# if [ $current_temp -gt 50 -a $current_temp -lt 60 ]
# then
# ipmitool -I lanplus -H $iDRAC -U $usr -P $pw raw 0x30 0x30 0x02 0xff 0x1e
# exit 1
# fi

# # 40% fans between 65C, 75C = 7920 RPM
# if [ $current_temp -ge 60 -a $current_temp -lt 70 ]
# then
# ipmitool -I lanplus -H $iDRAC -U $usr -P $pw raw 0x30 0x30 0x02 0xff 0x28
# exit 1
# fi

# # 50% fans between 75C, 80C = 9480 RPM
# if [ $current_temp -ge 70 -a $current_temp -lt 80 ]
# then
# ipmitool -I lanplus -H $iDRAC -U $usr -P $pw raw 0x30 0x30 0x02 0xff 0x32
# exit 1
# fi

# # 70% fans 80C+ = 12720 RPM
# if [ $current_temp -ge 80 ]
# then
# ipmitool -I lanplus -H $iDRAC -U $usr -P $pw raw 0x30 0x30 0x02 0xff 0x46
# exit 1
# fi