#!/bin/bash

LOGS_FILE='/tmp/data_logs.txt'
FILENAME='/tmp/logs.txt'
COUNT_SERVICE=$(sudo docker ps | grep communication | wc -l)
CONTAINER_ID=$(sudo docker ps --format "{{.ID}} {{.Image}}" \
| grep 'registry.gitlab.com/orca_ai/orcaai-ship/communication-engine-worker' \
| awk '{print $1}')


# Define patterns that mean success
PATTERNS=('upload_files .*●' 'Uploaded was')

#Assume failure
success=0

#Check if data is being uploaded
if [ "$COUNT_SERVICE" -eq 2 ]; then
   # Clear logs file each run
   > "$LOGS_FILE"
   sudo docker logs --tail 50 $CONTAINER_ID > $LOGS_FILE
   for PATTERN in "${PATTERNS[@]}"; do
      if grep -q "$PATTERN" "$LOGS_FILE"; then
        success=1
        break
      fi
   done
else
        echo "" >> $FILENAME
        echo "❌ Data is stuck - Only 1 commmunication service is running" >> $FILENAME
fi

if [ "$success" -eq 1 ]; then
    echo "" >> $FILENAME
    echo "✅ Data is being uploaded" >> $FILENAME
else
    echo "" >> $FILENAME
    echo "❌ Data is stuck or not uploading" >> $FILENAME
fi
