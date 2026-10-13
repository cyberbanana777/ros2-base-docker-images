# ros2-base-humble-jetson

ROS2 Humble на Ubuntu 18.04 для оригинального Jetson Nano (JetPack 4.6.x, L4T 32.7.1, ROS собран из исходников, CUDA через nvidia-рантайм).

**Актуальная версия: v1.0.0** ([история изменений](CHANGELOG.md))

```bash
docker pull registry.cookcloud.ru/base_images/ros2-base-humble-jetson:v1.0.0   # готовый образ (или ./build_image.sh для сборки)
./set_host_ids.sh                          # один раз: UID/GID в .env
docker compose up -d                       # запуск в фоне (или ./start_container.sh)
docker compose exec -u ros ros2-base-humble-jetson bash
docker compose down
```

В контейнер монтируется всё из `user_data/`: `developer_ws/` (рабочее пространство), `extra_files_to_container/` и `ros2_custom_config_setup/` (`cyclonedds.xml`, `banner.sh`, `setup.sh`, `bashrc.sh`, `dds_check.sh`). Настройки правятся без пересборки. Подробности в [общем README](../README.md).
