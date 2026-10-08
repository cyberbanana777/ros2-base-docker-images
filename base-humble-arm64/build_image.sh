#!/usr/bin/env bash
# Сборка базового образа ros2:base-humble-arm64: ./build_image.sh
# После сборки образ получает и второе имя unitree-hackathon:base-humble-arm64 (алиас для хакатона, место на диске не занимает).
set -euo pipefail
cd "$(dirname "$0")"
# UID/GID пользователя в контейнере = текущий пользователь хоста (обычно 1000),
# чтобы файлы в примонтированном src/ принадлежали ему, а не root.
# Переопределить: USER_UID=1001 USER_GID=1001 ./build_image.sh
USER_UID="${USER_UID:-$(id -u)}"
USER_GID="${USER_GID:-$(id -g)}"
sudo docker build -t "ros2:base-humble-arm64" \
    --build-arg USER_UID="${USER_UID}" --build-arg USER_GID="${USER_GID}" .
sudo docker tag "ros2:base-humble-arm64" "unitree-hackathon:base-humble-arm64"
