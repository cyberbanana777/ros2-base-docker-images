# Changelog

Формат: [Keep a Changelog](https://keepachangelog.com/ru/1.1.0/), версии `vMAJOR.MINOR.PATCH`.
Версия образа хранится в `.env` (`VERSION`).

## [v1.0.1] — 2026-10-13

Образ: `registry.cookcloud.ru/base_images/ros2-base-humble-jetson:v1.0.1`.

### Исправлено
- Вход через `docker exec` / `docker compose exec ... bash` давал root-шелл, и файлы в `user_data/developer_ws` создавались на хосте от root. Теперь интерактивный шелл root автоматически переключается на `ros`.

### Добавлено
- `KEEP_ROOT=1` (`docker compose exec -e KEEP_ROOT=1 <имя> bash`) оставляет root-шелл. `sudo -i` из-под `ros` по-прежнему даёт root.

### Известное ограничение
- Неинтерактивные команды (`docker exec <имя> colcon build`) по-прежнему идут от root: для них нужен `-u ros`.

## [v1.0.0] — 2026-10-13

Первый релиз. Образ: `registry.cookcloud.ru/base_images/ros2-base-humble-jetson:v1.0.0`.

### Добавлено
- Ubuntu 18.04, `dustynv/ros:humble-ros-base-l4t-r32.7.1`, ROS из исходников; фикс просроченного ключа репозитория ROS.
- CycloneDDS 0.10.x собирается, если в базовом образе нет `rmw_cyclonedds_cpp`.
- CycloneDDS 0.10.x как RMW по умолчанию, конфиг `cyclonedds.xml` на хосте (применяется без пересборки).
- Баннер при входе, цветной prompt с меткой `[docker:humble]`, цветные логи нод, автодополнение `ros2` и `colcon`.
- Команда `dds-check` и утилиты отладки сети и DDS (`iperf3`, `tcpdump`, `ddsperf`, `nload`, `iftop` и др.).
- Пользователь `ros` с `sudo` без пароля. UID/GID подгоняются под хост при старте контейнера (`HOST_UID`, `HOST_GID`) через `ros_entrypoint.sh` и `gosu`; образ универсален для любого UID.
- Автоматическое добавление пользователя в группы устройств `/dev/video*`, `/dev/ttyUSB*`, `/dev/ttyACM*` по реальному GID на хосте.
- Раскладка `user_data/`: `developer_ws/`, `extra_files_to_container/` и `ros2_custom_config_setup/` монтируются в `/home/ros`.
- Версия образа в `.env`, скрипты `build_image.sh`, `save_image.sh`, `load_image.sh`, `start_container.sh`, `set_host_ids.sh`.

### Изменено
- Имя образа: `registry.cookcloud.ru/base_images/ros2-base-humble-jetson:<версия>` (раньше `ros2:base-humble-jetson`); алиас `unitree-hackathon:*` убран.
- Рабочее пространство перенесено из `/developer_ws` в `/home/ros/developer_ws`.
- Контейнер стартует от root и сам переходит на `ros` (в образе нет `USER`): для входа через `docker exec` нужен `-u ros`.
