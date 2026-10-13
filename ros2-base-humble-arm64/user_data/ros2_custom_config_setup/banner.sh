#!/usr/bin/env bash
# --- This file can be edited. ---
# Баннер при входе в контейнер. Вызывается из bashrc.sh.

# Сообщение от организаторов: выводится под баннером, если не пустое.
# Например: MESSAGE="Wi-Fi: hackathon / 12345678 · помощь — канал #help"
MESSAGE=""

C='\033[1;36m'   # голубой
G='\033[0;32m'   # зелёный
Y='\033[0;33m'   # жёлтый
R='\033[0;31m'   # красный
B='\033[1m'      # жирный
N='\033[0m'      # сброс

distro="${ROS_DISTRO:-?}"

# Платформа и номер образа
platform="Ubuntu 22.04 · arm64"
image_name="ros2-base-humble-arm64"

# Реализация DDS и версия CycloneDDS
rmw="${RMW_IMPLEMENTATION:-по умолчанию}"
if [ "${RMW_IMPLEMENTATION}" = "rmw_cyclonedds_cpp" ]; then
    if [ -d /opt/cyclonedds_ws/install/cyclonedds ]; then
        rmw="${rmw} ${G}(CycloneDDS 0.10, собран из исходников)${N}"
    else
        rmw="${rmw} ${G}(CycloneDDS, штатный)${N}"
    fi
fi

# Конфиг DDS
if [ -z "${CYCLONEDDS_URI}" ]; then
    dds="${Y}не задан, настройки по умолчанию${N}"
else
    cfg="${CYCLONEDDS_URI#file://}"
    if [ -f "${cfg}" ]; then
        dds="${G}${cfg}${N}"
    else
        dds="${R}файл не найден: ${cfg}${N}"
    fi
fi

# Состояние рабочего пространства
if [ -f /home/ros/developer_ws/install/setup.bash ]; then
    ws="/home/ros/developer_ws ${G}(собран)${N}"
else
    ws="/home/ros/developer_ws ${Y}(ещё не собран: cd /home/ros/developer_ws && colcon build)${N}"
fi

echo -e "${C}════════════════════════════════════════════════════"
echo -e "   🐳  ТЫ ВНУТРИ DOCKER-КОНТЕЙНЕРА  ·  ROS2 ${distro^^}"
echo -e "      ${platform}\n      образ ${image_name}"
echo -e "════════════════════════════════════════════════════${N}"
echo -e "  Пользователь   $(whoami)"
echo -e "  ROS_DISTRO     ${distro}"
echo -e "  RMW            ${rmw}"
echo -e "  ROS_DOMAIN_ID  ${ROS_DOMAIN_ID:-0}"
echo -e "  DDS-конфиг     ${dds}"
echo -e "  Workspace      ${ws}"
if [ -n "${MESSAGE}" ]; then
    echo
    echo -e "  ${B}${MESSAGE}${N}"
fi
echo
