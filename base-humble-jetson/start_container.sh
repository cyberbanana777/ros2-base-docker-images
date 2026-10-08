#!/usr/bin/env bash
# Запуск контейнера без compose: ./start_container.sh
set -euo pipefail
cd "$(dirname "$0")"
sudo docker run \
	--runtime nvidia \
	-it \
	--rm \
	--network host \
	--ipc host \
	--privileged \
	-v /dev:/dev \
	-v "$(pwd)/src":/developer_ws/src \
	-v "$(pwd)/files_to_container":/files_to_container \
	-v "$(pwd)/ros2_custom_config_setup":/ros2_custom_config_setup \
	"ros2:base-humble-jetson"
