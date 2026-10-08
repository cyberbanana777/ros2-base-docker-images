# ros2:base-humble-jetson

ROS2 Humble на Ubuntu 18.04 для оригинального Jetson Nano (JetPack 4.6.x, L4T 32.7.1, ROS собран из исходников, CUDA через nvidia-рантайм).

```bash
./build_image.sh            # сборка
docker compose up -d        # запуск в фоне (или ./start_container.sh — разовый запуск)
docker compose exec base-humble-jetson bash
docker compose down
```

Настройки окружения лежат в `ros2_custom_config_setup/` и монтируются в контейнер, поэтому правятся без пересборки: `cyclonedds.xml` (DDS), `banner.sh` (баннер и сообщение организаторов), `setup.sh` (окружение ROS), `bashrc.sh` (терминал), `dds_check.sh` (команда `dds-check`). Подробности — в [общем README](../README.md).
