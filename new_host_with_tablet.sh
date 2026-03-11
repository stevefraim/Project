#!/bin/bash

# Prompt for user input
read -p "Enter the hostname: " hostname
read -p "Enter the IP address: " ip
read -p "Enter the PU label: " pu_num
read -p "Is there a tablet? " tablet

# Variables for file paths
hosts_file="/etc/hosts"
ansible_hosts_file="/etc/ansible/hosts"
ssh_hosts_dir="/etc/ansible/ansible-techops/Ansible/SSH-Hosts/"
ansible_hosts_dir="/etc/ansible/ansible-techops/Ansible/Ansible-Hosts/"

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


# Copy files to specified directories
sudo cp $hosts_file $ssh_hosts_dir
sudo cp $ansible_hosts_file $ansible_hosts_dir

# Navigate to the ansible-techops directory
cd /etc/ansible/ansible-techops

# Perform git operations
git add .
git commit -m "Updated hosts and ansible hosts files"
git push
