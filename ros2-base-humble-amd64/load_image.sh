#!/usr/bin/env bash
# Загрузка образа из файла: ./load_image.sh
set -euo pipefail
cd "$(dirname "$0")"
source .env
sudo docker load -i "ros2-base-humble-amd64-${VERSION}.tar"
