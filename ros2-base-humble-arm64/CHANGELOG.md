# Changelog

Формат: [Keep a Changelog](https://keepachangelog.com/ru/1.1.0/), версии `vMAJOR.MINOR.PATCH`.
Версия образа хранится в `.env` (`VERSION`).

## [v1.0.0] — 2026-10-13

Первый релиз. Образ: `registry.cookcloud.ru/base_images/ros2-base-humble-arm64:v1.0.0`.

### Добавлено
- Ubuntu 22.04, `ros:humble-ros-base-jammy` (arm64), ROS из apt.
- CycloneDDS 0.10.x как RMW по умолчанию, конфиг `cyclonedds.xml` на хосте (применяется без пересборки).
- Баннер при входе, цветной prompt с меткой `[docker:humble]`, цветные логи нод, автодополнение `ros2` и `colcon`.
- Команда `dds-check` и утилиты отладки сети и DDS (`iperf3`, `tcpdump`, `ddsperf`, `nload`, `iftop` и др.).
- Пользователь `ros` с `sudo` без пароля. UID/GID подгоняются под хост при старте контейнера (`HOST_UID`, `HOST_GID`) через `ros_entrypoint.sh` и `gosu`; образ универсален для любого UID.
- Автоматическое добавление пользователя в группы устройств `/dev/video*`, `/dev/ttyUSB*`, `/dev/ttyACM*` по реальному GID на хосте.
- Раскладка `user_data/`: `developer_ws/`, `extra_files_to_container/` и `ros2_custom_config_setup/` монтируются в `/home/ros`.
- Версия образа в `.env`, скрипты `build_image.sh`, `save_image.sh`, `load_image.sh`, `start_container.sh`, `set_host_ids.sh`.

### Изменено
- Имя образа: `registry.cookcloud.ru/base_images/ros2-base-humble-arm64:<версия>` (раньше `ros2:base-humble-arm64`); алиас `unitree-hackathon:*` убран.
- Рабочее пространство перенесено из `/developer_ws` в `/home/ros/developer_ws`.
- Контейнер стартует от root и сам переходит на `ros` (в образе нет `USER`): для входа через `docker exec` нужен `-u ros`.
