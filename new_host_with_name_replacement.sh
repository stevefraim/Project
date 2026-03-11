#!/bin/bash

# Host Configuration Script
echo "Ansible Host Configuration Script"
echo "1. New installation"
echo "2. Replacement"
echo "3. Rename hostname"
read -p "Choose operation type (1, 2 or 3): " operation_type

# Variables for file paths
hosts_file="/etc/hosts"
ansible_hosts_file="/etc/ansible/hosts"
ssh_hosts_dir="/etc/ansible/ansible-techops/Ansible/SSH-Hosts/"
ansible_hosts_dir="/etc/ansible/ansible-techops/Ansible/Ansible-Hosts/"

case $operation_type in
    1)
        echo "Selected: New installation"
        
        # Prompt for user input
        read -p "Enter the hostname: " hostname
        read -p "Enter the IP address: " ip
        read -p "Enter the PU label: " pu_num
        read -p "Is there a tablet (yes or no)? " tablet

        # Add entry to /etc/hosts
        sudo bash -c "echo -e '$ip\t$hostname' >> $hosts_file"

        # Add entry to /etc/ansible/hosts under [ships] section
        sudo bash -c "sed -i '/\[ships\]/a $hostname ansible_host=$ip ansible_port=39 ansible_user=$pu_num ansible_password=Orca123 ansible_sudo_pass=Orca123' $ansible_hosts_file"

        case "${tablet,,}" in
            yes|y)
                sudo bash -c "sed -i '/\[ships_with_tablet\]/a $hostname ansible_host=$ip ansible_port=39 ansible_user=$pu_num ansible_password=Orca123 ansible_sudo_pass=Orca123' $ansible_hosts_file"
                echo "Added host to [ships_with_tablet]"
                ;;
            no|n)
                echo "Not adding host to [ships_with_tablet]"
                ;;
            *)
                echo "Invalid answer. Please enter yes or no."
                exit 1
                ;;
        esac
        ;;
        
    2)
        echo "Selected: Replacement"
        
        # Prompt for user input (no tablet question for replacement)
        read -p "Enter the hostname: " hostname
        read -p "Enter the IP address: " ip
        read -p "Enter the PU label: " pu_num

        # Check if hostname exists in /etc/hosts
        if ! grep -q "[[:space:]]$hostname[[:space:]]*$" $hosts_file; then
            echo "Warning: Hostname '$hostname' not found in $hosts_file"
            read -p "Do you want to continue anyway? (yes/no): " continue_anyway
            case "${continue_anyway,,}" in
                yes|y)
                    echo "Continuing with replacement..."
                    ;;
                *)
                    echo "Operation cancelled."
                    exit 1
                    ;;
            esac
        fi

        # Replace entry in /etc/hosts
        sudo sed -i "/[[:space:]]$hostname[[:space:]]*$/c\\$ip\t$hostname" $hosts_file
        echo "Updated entry in $hosts_file"

        # Replace entry in /etc/ansible/hosts under [ships] section
        if grep -q "^$hostname ansible_host=" $ansible_hosts_file; then
            sudo sed -i "/^$hostname ansible_host=/c\\$hostname ansible_host=$ip ansible_port=39 ansible_user=$pu_num ansible_password=Orca123 ansible_sudo_pass=Orca123" $ansible_hosts_file
            echo "Updated entry in [ships] section of $ansible_hosts_file"
        else
            echo "Warning: Hostname '$hostname' not found in [ships] section of $ansible_hosts_file"
        fi

        # Replace entry in [ships_with_tablet] section if it exists there
        if sed -n '/^\[ships_with_tablet\]/,/^\[.*\]/p' $ansible_hosts_file | grep -q "^$hostname ansible_host="; then
            sudo sed -i "/^\[ships_with_tablet\]/,/^\[.*\]/{/^$hostname ansible_host=/c\\$hostname ansible_host=$ip ansible_port=39 ansible_user=$pu_num ansible_password=Orca123 ansible_sudo_pass=Orca123}" $ansible_hosts_file
            echo "Updated entry in [ships_with_tablet] section of $ansible_hosts_file"
        else
            echo "Hostname '$hostname' not found in [ships_with_tablet] section (this is normal if host doesn't have a tablet)"
        fi
        ;;
    
    3)
        echo "Selected: Rename hostname"
        read -p "Enter current hostname: " current_hostname
        read -p "Enter new hostname: " new_hostname

        # /etc/hosts format here is "IP hostname", so only check column 2.
        ip_from_hosts=$(awk -v h="$current_hostname" '$2==h{print $1; exit}' "$hosts_file")
        if [ -z "$ip_from_hosts" ]; then
            echo "Warning: Hostname '$current_hostname' not found in $hosts_file"
            read -p "Do you want to continue anyway? (yes/no): " continue_anyway
            case "${continue_anyway,,}" in
                yes|y)
                    echo "Continuing with rename (skipping $hosts_file update)..."
                    ;;
                *)
                    echo "Operation cancelled."
                    exit 1
                    ;;
            esac
        else
            # Replace the entire line using echo -e to keep the tab formatting consistent.
            sudo bash -c "sed -i \"/[[:space:]]$current_hostname[[:space:]]*$/c\\\\$ip_from_hosts\\t$new_hostname\" \"$hosts_file\""
            echo "Updated hostname in $hosts_file"
        fi

        # Update the vessel name only within the [ships] section.
        if sed -n '/^\[ships\]/,/^\[.*\]/p' $ansible_hosts_file | grep -q "^$current_hostname ansible_host="; then
            sudo sed -i "/^\[ships\]/,/^\[.*\]/{/^$current_hostname ansible_host=/s/^$current_hostname /$new_hostname /}" $ansible_hosts_file
            echo "Updated hostname in [ships] section of $ansible_hosts_file"
        else
            echo "Warning: Hostname '$current_hostname' not found in [ships] section of $ansible_hosts_file"
        fi

        # Update the vessel name only within the [ships_with_tablet] section.
        if sed -n '/^\[ships_with_tablet\]/,/^\[.*\]/p' $ansible_hosts_file | grep -q "^$current_hostname ansible_host="; then
            sudo sed -i "/^\[ships_with_tablet\]/,/^\[.*\]/{/^$current_hostname ansible_host=/s/^$current_hostname /$new_hostname /}" $ansible_hosts_file
            echo "Updated hostname in [ships_with_tablet] section of $ansible_hosts_file"
        else
            echo "Hostname '$current_hostname' not found in [ships_with_tablet] section (this is normal if host doesn't have a tablet)"
        fi
        ;;
    *)
        echo "Invalid option. Please choose 1, 2 or 3."
        exit 1
        ;;
esac

# Copy files to specified directories
sudo cp $hosts_file $ssh_hosts_dir
sudo cp $ansible_hosts_file $ansible_hosts_dir

# Navigate to the ansible-techops directory
 cd /etc/ansible/ansible-techops

# Optional git operations (useful when you want to test without pushing).
read -p "Do you want to commit and push changes? (yes/no): " do_git
case "${do_git,,}" in
    yes|y)
        git add .
        git commit -m "Updated hosts and ansible hosts files"
        git push
        ;;
    no|n)
        echo "Skipping git commit/push."
        ;;
    *)
        echo "Invalid answer. Skipping git commit/push."
        ;;
esac
