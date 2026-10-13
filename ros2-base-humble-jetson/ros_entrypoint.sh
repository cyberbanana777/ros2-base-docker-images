#!/bin/bash
# !!!! DO NOT EDIT !!!!
set -e

# От root: подгоняем пользователя ros под HOST_UID/HOST_GID и переходим на него.
# HOST_UID=0 оставляет root; без HOST_UID берутся UID/GID из образа.
if [ "$(id -u)" = "0" ] && [ "${HOST_UID:-}" != "0" ]; then
    new_uid=${HOST_UID:-$(id -u ros)}
    new_gid=${HOST_GID:-$(id -g ros)}
    old_uid=$(id -u ros)
    old_gid=$(id -g ros)

    [ "$old_gid" = "$new_gid" ] || groupmod -o -g "$new_gid" "$(id -gn ros)"
    if [ "$old_uid" != "$new_uid" ]; then
        usermod -o -u "$new_uid" ros
        # Только файлы старого владельца; bind-mount из user_data пропускаем.
        find /home/ros -xdev \( -path /home/ros/developer_ws \
            -o -path /home/ros/extra_files_to_container \
            -o -path /home/ros/ros2_custom_config_setup \) -prune -o \
            -user "$old_uid" -exec chown -h "$new_uid:$new_gid" {} +
    fi

    # Группы устройств по реальному GID на хосте (камеры, serial).
    for dev in /dev/video* /dev/ttyUSB* /dev/ttyACM*; do
        [ -e "$dev" ] || continue
        gid=$(stat -c %g "$dev")
        [ "$gid" != "0" ] || continue
        grp=$(getent group "$gid" | cut -d: -f1 || true)
        if [ -z "$grp" ]; then
            grp="hostgrp$gid"
            groupadd -g "$gid" "$grp"
        fi
        usermod -aG "$grp" ros
    done

    export HOME=/home/ros
    exec gosu ros "$0" "$@"
fi

[ -f /home/ros/ros2_custom_config_setup/setup.sh ] && source /home/ros/ros2_custom_config_setup/setup.sh
exec "$@"
