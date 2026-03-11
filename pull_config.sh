#!/bin/bash

CURRENT_VERSION=$(sudo docker ps | awk '$NF == "system-manager" {split($2, a, ":"); print a[2]}')
SHIP=$(hostname)

if $CURRENT_VERSION == 'v3.10.1' || $CURRENT_VERSION == 'v3.13.0'; then


  sudo docker run -it \
  -e CONFIG_PROVIDER_PROD_URL='54.158.9.202' \
  -e CUDA_VERSION=$(nvidia-smi | grep 'CUDA Version:' | cut -d ':' -f3 | sed -r 's/[|]+/ /g' | xargs) \
  -e DISPLAY=$(w -hs | grep -Po "[ \t]:[\.0-9A-Za-z:]+[ \t]" | sort -u | xargs) \
  -v ~/.docker/config.json:/root/.docker/config.json \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /orcaai/orcaai-storage:/orcaai/orcaai-storage \
  -v /dev:/dev \
  -v /lib/modules:/lib/modules \
  -v /etc/rc.local:/host/rc.local \
  -v /run/systemd/system:/run/systemd/system \
  -v /var/run/dbus/system_bus_socket:/var/run/dbus/system_bus_socket \
  -v $XAUTH:/root/.Xauthority \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  --network host \
  --privileged \
  --cap-add=ALL \
   registry.gitlab.com/orca_ai/orcaai-ship/ship-cli:$CURRENT_VERSION \
   make set-cloud-configs ship=$SHIP version=$CURRENT_VERSION
        
    if [ $? -ne 0 ]; then
        echo "Pull config is failed"
        exit 1
    fi


    sleep 10       

    # Restart Docker container
    sudo docker run --rm -it \
    -e CUDA_VERSION=$(nvidia-smi | grep 'CUDA Version:' | cut -d ':' -f3 | sed -r 's/[|]+/ /g' | xargs) \
    -e DISPLAY=$(w -hs | grep -Po "[ \t]:[\.0-9A-Za-z:]+[ \t]" | sort -u | xargs) \
    -e AUDIO_GROUP=$(getent group audio | cut -d: -f3) \
    -e XDG_RUNTIME_DIR_VALUE=${XDG_RUNTIME_DIR} \
    -v ~/.docker/config.json:/root/.docker/config.json \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /orcaai/orcaai-storage:/orcaai/orcaai-storage \
    -v /dev:/dev \
    -v /lib/modules:/lib/modules \
    -v /etc/rc.local:/host/rc.local \
    -v /run/systemd/system:/run/systemd/system \
    -v /var/run/dbus/system_bus_socket:/var/run/dbus/system_bus_socket \
    -v $XAUTH:/root/.Xauthority \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -v ${XDG_RUNTIME_DIR}/pulse/native:${XDG_RUNTIME_DIR_VALUE}/pulse/native \
    --network host \
    --privileged \
    --cap-add=ALL \
    registry.gitlab.com/orca_ai/orcaai-ship/ship-cli:$CURRENT_VERSION \
    make restart-all

    # Pause to ensure Docker command completes
    sleep 30
fi