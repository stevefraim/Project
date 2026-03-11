#!/usr/bin/env bash
set -uo pipefail

SELECTED_HOSTS_FILE="${1:-/etc/ansible/playbooks/shipmate/selected_hosts}"
RECORDINGS_URL="http://localhost:3000/recordings"

CAMERAS=(
  "day_center"
  "day_right"
  "day_right_2nd"
  "day_left"
  "day_left_2nd"
  "thermal_center"
  "thermal_right"
  "thermal_left"
)

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

array_contains() {
  local needle="$1"
  shift
  local item
  for item in "$@"; do
    [[ "$item" == "$needle" ]] && return 0
  done
  return 1
}

validate_prerequisites() {
  if [[ ! -r "$SELECTED_HOSTS_FILE" ]]; then
    echo "Cannot read hosts file: $SELECTED_HOSTS_FILE" >&2
    exit 1
  fi

  if ! command -v sshpass >/dev/null 2>&1; then
    echo "Missing dependency: sshpass" >&2
    exit 1
  fi

  if ! command -v ssh >/dev/null 2>&1; then
    echo "Missing dependency: ssh" >&2
    exit 1
  fi

  if ! command -v date >/dev/null 2>&1; then
    echo "Missing dependency: date" >&2
    exit 1
  fi
}

load_vessels() {
  SHIP_ALIAS=()
  SHIP_HOST=()
  SHIP_PORT=()
  SHIP_USER=()
  SHIP_PASS=()

  local line ship host port user pass

  while IFS= read -r line; do
    [[ -z "${line//[[:space:]]/}" ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue

    ship="${line%%[[:space:]]*}"
    host="$(extract_kv "$line" "ansible_host" || true)"
    port="$(extract_kv "$line" "ansible_port" || true)"
    user="$(extract_kv "$line" "ansible_user" || true)"
    pass="$(extract_kv "$line" "ansible_password" || true)"

    [[ -z "$host" ]] && host="$ship"
    [[ -z "$port" ]] && port="22"

    SHIP_ALIAS+=("$ship")
    SHIP_HOST+=("$host")
    SHIP_PORT+=("$port")
    SHIP_USER+=("$user")
    SHIP_PASS+=("$pass")
  done < "$SELECTED_HOSTS_FILE"

  if [[ ${#SHIP_ALIAS[@]} -eq 0 ]]; then
    echo "No vessels were loaded from: $SELECTED_HOSTS_FILE" >&2
    exit 1
  fi
}

choose_vessel() {
  echo "Available vessels from selected_hosts:"
  local i
  for i in "${!SHIP_ALIAS[@]}"; do
    printf '  %2d) %s (%s:%s)\n' \
      "$((i + 1))" "${SHIP_ALIAS[$i]}" "${SHIP_HOST[$i]}" "${SHIP_PORT[$i]}"
  done

  local choice idx
  while true; do
    read -r -p "Choose vessel number: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]]; then
      idx=$((choice - 1))
      if (( idx >= 0 && idx < ${#SHIP_ALIAS[@]} )); then
        CHOSEN_INDEX="$idx"
        return
      fi
    fi
    echo "Invalid vessel number. Enter 1-${#SHIP_ALIAS[@]}"
  done
}

parse_duration_seconds() {
  local input="$1"
  local cleaned
  cleaned="$(echo "$input" | tr -d '[:space:]')"

  if [[ "$cleaned" =~ ^[0-9]+$ ]]; then
    printf '%s' "$cleaned"
    return 0
  fi

  if [[ "$cleaned" =~ ^([0-9]+)(s|sec|secs|second|seconds)$ ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
    return 0
  fi

  if [[ "$cleaned" =~ ^([0-9]+)(m|min|mins|minute|minutes)$ ]]; then
    printf '%s' "$((BASH_REMATCH[1] * 60))"
    return 0
  fi

  if [[ "$cleaned" =~ ^([0-9]+)(h|hr|hrs|hour|hours)$ ]]; then
    printf '%s' "$((BASH_REMATCH[1] * 3600))"
    return 0
  fi

  return 1
}

ask_duration() {
  local input parsed
  while true; do
    read -r -p "Recording duration (1800 / 30m / 1h): " input
    if parsed="$(parse_duration_seconds "$input")"; then
      if (( parsed > 0 )); then
        DURATION_SECONDS="$parsed"
        return
      fi
    fi
    echo "Invalid duration. Use seconds or suffix s/m/h."
  done
}

ask_timestamp() {
  local input parsed
  while true; do
    read -r -p "Trigger date/time (YYYY-MM-DD HH:MM:SS or YYYY-MM-DDTHH:MM:SS): " input
    input="${input//T/ }"
    if parsed="$(date -d "$input" '+%Y-%m-%dT%H:%M:%S.000000' 2>/dev/null)"; then
      TRIGGER_TIMESTAMP="$parsed"
      return
    fi
    echo "Invalid date/time format."
  done
}

ask_cameras() {
  local answer

  while true; do
    read -r -p "Record all 8 cameras? (y/n): " answer
    answer="${answer,,}"

    case "$answer" in
      y|yes)
        SELECTED_CAMERAS=("${CAMERAS[@]}")
        return
        ;;
      n|no)
        echo "Available cameras: ${CAMERAS[*]}"
        echo "Enter comma-separated camera IDs, example: day_center,thermal_left"

        local input
        read -r -p "Camera IDs: " input

        IFS=',' read -r -a raw_list <<< "$input"
        SELECTED_CAMERAS=()

        local cam trimmed valid=true
        for cam in "${raw_list[@]}"; do
          trimmed="$(echo "$cam" | xargs)"
          [[ -z "$trimmed" ]] && continue

          if ! array_contains "$trimmed" "${CAMERAS[@]}"; then
            echo "Unknown camera: $trimmed"
            valid=false
            break
          fi

          if ! array_contains "$trimmed" "${SELECTED_CAMERAS[@]}"; then
            SELECTED_CAMERAS+=("$trimmed")
          fi
        done

        if [[ "$valid" == true && ${#SELECTED_CAMERAS[@]} -gt 0 ]]; then
          return
        fi

        echo "Invalid camera selection. Try again."
        ;;
      *)
        echo "Please answer y or n."
        ;;
    esac
  done
}

build_camera_json() {
  local first=true
  CAMERA_JSON="["

  local cam
  for cam in "${SELECTED_CAMERAS[@]}"; do
    if [[ "$first" == true ]]; then
      first=false
    else
      CAMERA_JSON+=", "
    fi
    CAMERA_JSON+="\"$cam\""
  done

  CAMERA_JSON+="]"
}

build_trigger_label() {
  local mins hours
  if (( DURATION_SECONDS % 3600 == 0 )); then
    hours=$((DURATION_SECONDS / 3600))
    TRIGGER_LABEL="${hours}h_recording"
    return
  fi

  if (( DURATION_SECONDS % 60 == 0 )); then
    mins=$((DURATION_SECONDS / 60))
    TRIGGER_LABEL="${mins}min_recording"
    return
  fi

  TRIGGER_LABEL="${DURATION_SECONDS}s_recording"
}

build_payload() {
  PAYLOAD=$(cat <<JSON
{"duration": ${DURATION_SECONDS}, "triggerTimestamp": "${TRIGGER_TIMESTAMP}", "trigger": "${TRIGGER_LABEL}", "videoContainer": "mp4", "recordScreen": true, "recordSensors": true, "cameraIds": ${CAMERA_JSON}}
JSON
)
}

confirm_summary() {
  local idx="$CHOSEN_INDEX"

  echo
  echo "Summary"
  echo "  Vessel: ${SHIP_ALIAS[$idx]} (${SHIP_HOST[$idx]}:${SHIP_PORT[$idx]})"
  echo "  Duration: ${DURATION_SECONDS} seconds"
  echo "  Trigger timestamp: ${TRIGGER_TIMESTAMP}"
  echo "  Trigger label: ${TRIGGER_LABEL}"
  echo "  Cameras: ${SELECTED_CAMERAS[*]}"
  echo

  local confirm
  read -r -p "Proceed and send recording request? (y/n): " confirm
  confirm="${confirm,,}"
  [[ "$confirm" == "y" || "$confirm" == "yes" ]]
}

send_remote_curl() {
  local idx="$CHOSEN_INDEX"
  local ship host port user pass

  ship="${SHIP_ALIAS[$idx]}"
  host="${SHIP_HOST[$idx]}"
  port="${SHIP_PORT[$idx]}"
  user="${SHIP_USER[$idx]}"
  pass="${SHIP_PASS[$idx]}"

  if [[ -z "$user" || -z "$pass" ]]; then
    echo "Cannot connect to $ship: missing ansible_user or ansible_password" >&2
    exit 1
  fi

  local ssh_target="${user}@${host}"

  sshpass -p "$pass" \
    ssh \
      -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      -o ConnectTimeout=10 \
      -p "$port" \
      "$ssh_target" \
      "curl --silent --show-error --fail --request POST '$RECORDINGS_URL' --header 'Content-Type: application/json' --data '$PAYLOAD'"
}

main() {
  validate_prerequisites
  load_vessels
  choose_vessel
  ask_duration
  ask_timestamp
  ask_cameras
  build_camera_json
  build_trigger_label
  build_payload

  if ! confirm_summary; then
    echo "Canceled."
    exit 0
  fi

  send_remote_curl
  echo
  echo "Recording request sent successfully."
}

main "$@"
