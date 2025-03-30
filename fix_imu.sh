#!/bin/bash

# Define the filename for the logs
LOG_DIR="/tmp/"
FILENAME="${LOG_DIR}fix_imu.txt"


# Remove and reload device rules
sudo rm -r /dev/ttyIMU
sudo udevadm control --reload-rules
sudo udevadm trigger
sudo usbreset 10c4:ea60
sudo docker restart imu-service


sleep 20

# Check if the issue is fixed and append the output to the log file
echo "" >> $FILENAME
echo "The USBs ports which devices are connected to are:" >> $FILENAME
ls /dev/ttyUSB* >> $FILENAME 2>&1
echo "" >> $FILENAME
echo "Checking IMU data status after resetting:" >> $FILENAME
curl http://localhost:5007/data >> $FILENAME 2>&1
