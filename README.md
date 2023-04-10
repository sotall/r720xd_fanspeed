# **Project Title**


Temperature Monitor and Fan Controller
## **Description**

This project provides a bash script to monitor the temperature of various components of a server and control the speed of the fans accordingly. The script checks the temperature of the CPUs, exhaust, and GPUs using the IPMI tool and Nvidia-smi (if installed). Based on the temperature readings, the script sets the fan speed to keep the temperature within a safe range. The script takes three arguments: iDRAC IP, iDRAC username, and iDRAC password.

## **Usage**

To use the script, open a terminal window and run the following command:

bash

``` bash
./temp_monitor_fan_controller.sh <iDRAC IP> <iDRAC username> <iDRAC password>
```

Replace '`<iDRAC IP>`', '`<iDRAC username>`', and '`<iDRAC password>`' with the IP address, username, and password of the iDRAC of the server, respectively.

## **Example**

``` bash
./temp_monitor_fan_controller.sh 192.168.1.100 admin password
```

In this example, the script will monitor the temperature of the server with the IP address '`192.168.1.100`' using the iDRAC username '`admin`' and '`password`' password.


## **Requirements**

    Bash shell
    IPMI tool
    Nvidia-smi (optional)