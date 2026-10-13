
# --- This file can be edited. ---
# Конфиг образа ros2-base-humble-arm64: монтируется в /home/ros/ros2_custom_config_setup,
# подключается entrypoint-ом (set -e, поэтому проверки через if/fi) и в каждом bash.

# base environment
# Путь к ROS: 18.04 (из исходников) — .../install/setup.bash, 22.04 (apt) — .../setup.bash
if [ -z "${ROS_DISTRO}" ]; then
    ROS_DISTRO=$(ls /opt/ros | head -n1)
fi
if [ -f "/opt/ros/${ROS_DISTRO}/install/setup.bash" ]; then
    source "/opt/ros/${ROS_DISTRO}/install/setup.bash"
else
    source "/opt/ros/${ROS_DISTRO}/setup.bash"
fi

# CycloneDDS 0.10, собранный отдельно (если не штатный)
if [ -f /opt/cyclonedds_ws/install/setup.bash ]; then
    source /opt/cyclonedds_ws/install/setup.bash
fi

# цветные логи нод по уровню (WARN жёлтым, ERROR красным), в том числе в ros2 launch
export RCUTILS_COLORIZED_OUTPUT=1

# dds setup
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
# Без cyclonedds.xml CycloneDDS работает с настройками по умолчанию
if [ -f /home/ros/ros2_custom_config_setup/cyclonedds.xml ]; then
    export CYCLONEDDS_URI=file:///home/ros/ros2_custom_config_setup/cyclonedds.xml
fi

# workspace участников
if [ -f /home/ros/developer_ws/install/setup.bash ]; then
    source /home/ros/developer_ws/install/setup.bash
fi
