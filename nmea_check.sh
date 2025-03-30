#!/bin/bash

# Define the lists of patterns
GYRO=("HDG" "HDT" "HE")
GPS=("GP" "RMB" "ROT" "RMC" "GLL" "GGA")
SPEEDLOG=("VTG" "ZDA")
WIND=("WI" "MWV" "MWD")
RADAR=("RA" "TTM")
DEPTH=("SD" "DPT" "DBK" "DBS" "DBT")
AIS=("AI" "VDM" "VDO")

# Define Moxa IP addresses
moxa_devices=("192.168.1.250" "192.168.1.251")

# Ports to monitor
ports=("4001" "4002" "4003" "4004")

# Function to check patterns in the captured traffic
check_patterns() {
  local device_ip=$1
  local port=$2
  local data=$3

  local signals_found=()

  # Check each list of patterns
  for list_name in "GYRO" "GPS" "SPEEDLOG" "WIND" "RADAR" "DEPTH" "AIS"; do
    local patterns_var="${list_name}[@]"
    local patterns=("${!patterns_var}")

    # Check for pattern matches in the data
    for pattern in "${patterns[@]}"; do
      match_count=$(echo "$data" | grep -o "$pattern" | wc -l)

      # If a pattern is found, record it
      if [ "$match_count" -gt 0 ]; then
        signals_found+=("$list_name")
        break  # Stop checking other patterns if we found at least one match
      fi
    done
  done

  # Format and print the result
  if [ ${#signals_found[@]} -eq 0 ]; then
    echo "Port $port on $device_ip is empty."
  else
    # Remove duplicates and format the output
    unique_signals=$(printf "%s\n" "${signals_found[@]}" | sort -u | tr '\n' ',' | sed 's/,$//')
    echo "Port $port on $device_ip - $unique_signals"
  fi
}

# Function to capture traffic from a port for a Moxa device
capture_traffic() {
  local device_ip=$1
  local port=$2

  echo "Capturing traffic from $device_ip on port $port..."

  # Capture traffic on the specific port
  local output=$(timeout 5 sudo tcpdump -i enp3s0 host "$device_ip" and port "$port" -A -c 20 2>/dev/null)

  echo "$output"
}

# Loop through Moxa devices and ports
for moxa in "${moxa_devices[@]}"; do
  # Ping to check if Moxa is reachable
  if ping -c 2 -W 2 "$moxa" &> /dev/null; then
    echo "$moxa is reachable."

    # Check each port
    for port in "${ports[@]}"; do
      # Capture traffic from the current port
      traffic=$(capture_traffic "$moxa" "$port")
      
      # Check if traffic was captured and analyze it
      check_patterns "$moxa" "$port" "$traffic"
    done
  else
    echo "$moxa is not reachable."
  fi
done
