#!/bin/bash

# Inventory file and playbook
INVENTORY_FILE="/etc/ansible/playbooks/shipmate/selected_hosts"

# List of hosts in the [deploy] group
echo ""
echo "The following ships will be affected:"
echo ""
awk '{print $1, $4}' "$INVENTORY_FILE"
echo
echo ""


ansible-playbook -i "$INVENTORY_FILE" data_check_playbook.yml -f 50 -T 150