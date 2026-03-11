#!/bin/bash

CFG_FILE="/usr/NX/etc/server.cfg"
PASS='Orca123'

sudo sed -i -E \
    's/^#?[[:space:]]*EnablePasswordDB[[:space:]]*[01]/EnablePasswordDB 1/' \
    "$CFG_FILE"


echo "EnablePasswordDB set to 1 in $CFG_FILE"


sudo /usr/NX/bin/nxserver --useradd $USER <<EOF
$PASS
$PASS
EOF

if [ $? -ne 0 ]; then
    echo "Previous command failed. Exiting."
    exit 1
fi



echo "Added NX user: $USER"

sudo rm ./fix_enable_password_db.sh

echo "The script is deleted"