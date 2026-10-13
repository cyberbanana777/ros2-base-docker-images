#!/usr/bin/env bash
# Записывает UID/GID текущего пользователя в .env для docker compose: ./set_host_ids.sh
set -euo pipefail
cd "$(dirname "$0")"
sed -i '/^HOST_[UG]ID=/d' .env
printf 'HOST_UID=%s\nHOST_GID=%s\n' "$(id -u)" "$(id -g)" >> .env
echo "Записано в .env: HOST_UID=$(id -u) HOST_GID=$(id -g)"
