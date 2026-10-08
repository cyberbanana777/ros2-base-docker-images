#!/usr/bin/env bash
# Сохранение образа в файл для переноса на другое устройство: ./save_image.sh
set -euo pipefail
cd "$(dirname "$0")"
sudo docker save "ros2:base-humble-jetson" "unitree-hackathon:base-humble-jetson" -o "ros2-base-humble-jetson.tar"   # в архиве оба имени
sudo chown "$(id -u):$(id -g)" "ros2-base-humble-jetson.tar"
echo "Сохранено: ros2-base-humble-jetson.tar"
