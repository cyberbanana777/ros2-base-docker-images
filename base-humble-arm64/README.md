# ros2:base-humble-arm64

ROS2 Humble на Ubuntu 22.04, arm64 (бинарные пакеты из apt).

```bash
./build_image.sh            # сборка
docker compose up -d        # запуск в фоне (или ./start_container.sh — разовый запуск)
docker compose exec base-humble-arm64 bash
docker compose down
```

Настройки окружения лежат в `ros2_custom_config_setup/` и монтируются в контейнер, поэтому правятся без пересборки: `cyclonedds.xml` (DDS), `banner.sh` (баннер и сообщение организаторов), `setup.sh` (окружение ROS), `bashrc.sh` (терминал), `dds_check.sh` (команда `dds-check`). Подробности — в [общем README](../README.md).
