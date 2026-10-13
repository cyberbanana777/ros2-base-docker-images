#!/usr/bin/env bash
# Сохранение образа в файл для переноса на другое устройство: ./save_image.sh
set -euo pipefail
cd "$(dirname "$0")"
source .env
sudo docker save "registry.cookcloud.ru/base_images/ros2-base-humble-jetson:${VERSION}" -o "ros2-base-humble-jetson-${VERSION}.tar"
sudo chown "$(id -u):$(id -g)" "ros2-base-humble-jetson-${VERSION}.tar"
echo "Сохранено: ros2-base-humble-jetson-${VERSION}.tar"
