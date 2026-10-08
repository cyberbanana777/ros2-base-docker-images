
# --- This file can be edited. ---
# Конфиг образа base-humble-jetson: лежит на хосте и монтируется
# в контейнер в /ros2_custom_config_setup. Подключается entrypoint-ом и в каждом bash.
# Важно: файл подключается из entrypoint с `set -e`, поэтому все проверки здесь
# через if/fi, а не через `[ ... ] && ...` (иначе контейнер может не стартовать).

# base environment
# Путь к окружению ROS зависит от образа:
#   Ubuntu 18.04 (jetson-containers, ROS собран из исходников): /opt/ros/<distro>/install/setup.bash
#   Ubuntu 22.04 (бинарные пакеты из apt):                       /opt/ros/<distro>/setup.bash
if [ -z "${ROS_DISTRO}" ]; then
    ROS_DISTRO=$(ls /opt/ros | head -n1)
fi
if [ -f "/opt/ros/${ROS_DISTRO}/install/setup.bash" ]; then
    source "/opt/ros/${ROS_DISTRO}/install/setup.bash"
else
    source "/opt/ros/${ROS_DISTRO}/setup.bash"
fi

# CycloneDDS 0.10, собранный из исходников поверх ROS
# (в Ubuntu 18.04 — если его не было в базовом образе; в 22.04 CycloneDDS штатный)
if [ -f /opt/cyclonedds_ws/install/setup.bash ]; then
    source /opt/cyclonedds_ws/install/setup.bash
fi

# цветные логи нод по уровню (WARN жёлтым, ERROR красным), в том числе в ros2 launch
export RCUTILS_COLORIZED_OUTPUT=1

# dds setup
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
# Конфиг CycloneDDS лежит рядом с этим файлом. Если его убрать, CycloneDDS
# работает с настройками по умолчанию.
if [ -f /ros2_custom_config_setup/cyclonedds.xml ]; then
    export CYCLONEDDS_URI=file:///ros2_custom_config_setup/cyclonedds.xml
fi

# workspace участников
if [ -f /developer_ws/install/setup.bash ]; then
    source /developer_ws/install/setup.bash
fi
