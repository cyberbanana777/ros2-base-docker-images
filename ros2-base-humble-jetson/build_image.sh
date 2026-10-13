#!/usr/bin/env bash
# Сборка образа registry.cookcloud.ru/base_images/ros2-base-humble-jetson:<VERSION>: ./build_image.sh
# Версия берётся из .env (VERSION); переопределить: VERSION=v1.0.1 ./build_image.sh
# Публикация: sudo docker push <имя образа>:<версия>
set -euo pipefail
cd "$(dirname "$0")"
source .env
VERSION="${VERSION:?}"
sudo docker build -t "registry.cookcloud.ru/base_images/ros2-base-humble-jetson:${VERSION}" .
