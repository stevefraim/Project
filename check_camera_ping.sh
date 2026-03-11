#!/usr/bin/env bash
set -uo pipefail

SELECTED_HOSTS_FILE="${1:-/etc/ansible/playbooks/shipmate/selected_hosts}"

IP_ADDRESSES=(
  "192.168.1.89"
  "192.168.1.90"
  "192.168.1.91"
  "192.168.1.92"
  "192.168.1.93"
  "192.168.1.30"
  "192.168.1.31"
  "192.168.1.32"
)

if [[ ! -r "$SELECTED_HOSTS_FILE" ]]; then
  echo "Cannot read hosts file: $SELECTED_HOSTS_FILE" >&2
  exit 1
fi

if ! command -v sshpass >/dev/null 2>&1; then
  echo "Missing dependency: sshpass" >&2
  exit 1
fi

extract_kv() {
  local line="$1"
  local key="$2"
  local token

  for token in $line; do
    if [[ "$token" == "$key="* ]]; then
      token="${token#*=}"
      token="${token%\"}"
      token="${token#\"}"
      printf '%s' "$token"
      return 0
    fi
  done
  return 1
}

total_hosts=0
failed_hosts=0

while IFS= read -r line; do
  [[ -z "${line//[[:space:]]/}" ]] && continue
  [[ "$line" =~ ^[[:space:]]*# ]] && continue

  ship="${line%%[[:space:]]*}"
  host="$(extract_kv "$line" "ansible_host" || true)"
  port="$(extract_kv "$line" "ansible_port" || true)"
  user="$(extract_kv "$line" "ansible_user" || true)"
  password="$(extract_kv "$line" "ansible_password" || true)"

  [[ -z "$host" ]] && host="$ship"
  [[ -z "$port" ]] && port="22"

  if [[ -z "$user" || -z "$password" ]]; then
    echo "Skipping $ship: missing ansible_user or ansible_password"
    ((failed_hosts++))
    continue
  fi

  ((total_hosts++))
  echo
  echo "Checking ping from $ship ($host:$port)..."

  ping_commands=""
  for ip in "${IP_ADDRESSES[@]}"; do
    ping_commands+="ping -c 3 -W 2 '$ip' > /dev/null 2>&1 && "
    ping_commands+="echo 'Ping to $ip: SUCCESS' || echo 'Ping to $ip: FAILED'; "
  done

  if ! sshpass -p "$password" ssh \
      -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      -o ConnectTimeout=8 \
      -p "$port" \
      "$user@$host" \
      "$ping_commands"; then
    echo "SSH command failed on $ship"
    ((failed_hosts++))
  fi
done < "$SELECTED_HOSTS_FILE"

echo
echo "Ping check process completed."
echo "Hosts processed: $total_hosts"
echo "Hosts with failures or skipped: $failed_hosts"
