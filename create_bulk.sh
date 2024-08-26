#!/bin/bash

# Path to the file containing the list of names
NAMES_FILE="ships_with_new_imu.txt"

# Path to the Ansible hosts file
HOSTS_FILE="/etc/ansible/hosts"

# Temporary file to store matches
TEMP_FILE=/var/tmp/temp.txt

# Ensure the temporary file is empty at the start
: > "$TEMP_FILE"

# Check if [imu] section exists
if grep -q "^\[imu\]" "$HOSTS_FILE"; then
    # Extract the content of [imu] section to compare later
    UNREACHABLE_SHIPS=$(sed -n '/^\[imu\]/,/^\[/p' "$HOSTS_FILE" | grep -v '^\[')
else
    # If the section does not exist, create it at the end of the file
    echo "[imu]" >> "$HOSTS_FILE"
    UNREACHABLE_SHIPS=""
fi

# Read the names from the list and grep in the hosts file
while IFS= read -r name; do
    # Grep each name from the hosts file and append to TEMP_FILE if it's not already in the [imu] section
    if grep -wq "$name" "$HOSTS_FILE" && ! echo "$UNREACHABLE_SHIPS" | grep -wq "$name"; then
        grep -w "$name" "$HOSTS_FILE" >> "$TEMP_FILE"
    fi
done < "$NAMES_FILE"

# Remove any duplicate lines in TEMP_FILE
sort -u "$TEMP_FILE" -o "$TEMP_FILE"

# Append unique matches to the [imu] section
if [ -s "$TEMP_FILE" ]; then
    sed -i '/^\[imu\]/r '"$TEMP_FILE" "$HOSTS_FILE"
fi

# Clean up temporary file
rm -f "$TEMP_FILE"
