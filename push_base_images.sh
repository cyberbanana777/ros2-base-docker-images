#!/usr/bin/env bash
# Публикация базовых образов в реестр, откуда их берут extra-репозитории (go1-hackathon-images, jetbot-images).
# Использование: ./push_base_images.sh <адрес реестра> [arm64|amd64|jetson ...]
#   например:    ./push_base_images.sh registry.local:5000
# Без списка отправляет те базовые образы, которые есть на этой машине.
# Каждый образ уходит под двумя именами (слои в реестре хранятся один раз):
#   <реестр>/ros2:base-humble-<вариант>               главное имя, от него строятся extra-образы
#   <реестр>/unitree-hackathon:base-humble-<вариант>  алиас для участников хакатона
set -euo pipefail
REGISTRY="${1:?Укажи адрес реестра, например registry.local:5000}"; shift || true
declare -A TAG=( [arm64]=base-humble-arm64 [amd64]=base-humble-amd64 [jetson]=base-humble-jetson )
if [ "$#" -gt 0 ]; then list=("$@"); else list=(arm64 amd64 jetson); fi
pushed=0
for k in "${list[@]}"; do
  [ -n "${TAG[$k]:-}" ] || { echo "Неизвестный образ: $k (arm64|amd64|jetson)" >&2; exit 1; }
  local_ref="ros2:${TAG[$k]}"
  if ! sudo docker image inspect "$local_ref" > /dev/null 2>&1; then
    echo "Пропускаю $local_ref: образа нет на этой машине"
    continue
  fi
  for repo in ros2 unitree-hackathon; do
    remote_ref="${REGISTRY}/${repo}:${TAG[$k]}"
    sudo docker tag "$local_ref" "$remote_ref"
    sudo docker push "$remote_ref"
  done
  pushed=$((pushed + 1))
done
echo "Отправлено образов: $pushed (каждый под двумя именами)"
