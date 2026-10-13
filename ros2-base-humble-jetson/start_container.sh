#!/usr/bin/env bash
# Запуск контейнера без compose: ./start_container.sh
set -euo pipefail
cd "$(dirname "$0")"
source .env
sudo docker run \
	--runtime nvidia \
	-it \
	--rm \
	--network host \
	--ipc host \
	--privileged \
	-e HOST_UID="$(id -u)" \
	-e HOST_GID="$(id -g)" \
	-v /dev:/dev \
	-v "$(pwd)/user_data/developer_ws":/home/ros/developer_ws \
	-v "$(pwd)/user_data/extra_files_to_container":/home/ros/extra_files_to_container \
	-v "$(pwd)/user_data/ros2_custom_config_setup":/home/ros/ros2_custom_config_setup \
	"registry.cookcloud.ru/base_images/ros2-base-humble-jetson:${VERSION}"
