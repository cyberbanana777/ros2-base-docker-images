# ros2-base-images: базовые образы ROS2 Humble

Три базовых Docker-образа на ROS2 Humble. Они не привязаны к конкретному роботу: на них строятся extra-образы из соседних репозиториев, а ещё их можно использовать сами по себе на любом ПК и одноплатнике нужной архитектуры.

| Папка | Образ | Версия | Ubuntu | Железо | Что внутри |
|---|---|---|---|---|---|
| `ros2-base-humble-arm64` | `registry.cookcloud.ru/base_images/ros2-base-humble-arm64` | v1.0.0 | 22.04 | arm64 | ROS из apt |
| `ros2-base-humble-amd64` | `registry.cookcloud.ru/base_images/ros2-base-humble-amd64` | v1.0.0 | 22.04 | amd64 | ROS из apt |
| `ros2-base-humble-jetson` | `registry.cookcloud.ru/base_images/ros2-base-humble-jetson` | v1.0.0 | 18.04 | Jetson Nano (JetPack 4.6.x, L4T 32.7.1) | ROS собран из исходников, CUDA через nvidia-рантайм |

Версия каждого образа хранится в `.env` его папки (`VERSION`), а история изменений в `CHANGELOG.md` там же. Таблица выше показывает актуальные версии: при выпуске новой версии её нужно обновить.

## Готовые образы

Образы лежат в реестре `registry.cookcloud.ru` (при необходимости `docker login registry.cookcloud.ru`):

```bash
docker pull registry.cookcloud.ru/base_images/ros2-base-humble-jetson:v1.0.0   # Jetson Nano (arm64, Ubuntu 18.04)
docker pull registry.cookcloud.ru/base_images/ros2-base-humble-arm64:v1.0.0    # arm64, Ubuntu 22.04
docker pull registry.cookcloud.ru/base_images/ros2-base-humble-amd64:v1.0.0    # amd64, Ubuntu 22.04
```

Нужен только свой вариант: на Jetson с 6 ГБ свободного места пулить все три не стоит. Запускать образ можно из папки проекта (`docker compose up -d`, версия берётся из `.env`) или своей командой `docker run`.

Кто на чём строится (у дополнительных образов тег начинается с `extra-`, у базовых с `base-`):

| Репозиторий (gihub, аналогичный текущему)| Образ | Основан на |
|---|---|---|
| [unitree-go1-hackathon-images](https://github.com/cyberbanana777/unitree-go1-hackathon-images) | `unitree-hackathon:extra-humble-jetson-camera` | `registry.cookcloud.ru/base_images/ros2-base-humble-jetson:v1.0.0` |
| [mirea-jetbot-images](https://github.com/cyberbanana777/mirea-jetbot-images) | `registry.cookcloud.ru/jetbot_mirea/extra-humble-amd64-host:v1.0.0` | `registry.cookcloud.ru/base_images/ros2-base-humble-amd64:v1.0.0` |
| [mirea-jetbot-images](https://github.com/cyberbanana777/mirea-jetbot-images) | `registry.cookcloud.ru/jetbot_mirea/extra-humble-arm64-robot:v1.0.0` | `registry.cookcloud.ru/base_images/ros2-base-humble-arm64:v1.0.0` |
| - приватный репозиторий - | `registry.cookcloud.ru/unitree_go1_hackathon/extra-humble-amd64-digital-twin:v0.1.0` | `registry.cookcloud.ru/base_images/ros2-base-humble-amd64:v1.0.0` |

Во всех образах семейства (и в extra-образах из других репозиториев) одинаково: CycloneDDS 0.10, свой конфиг DDS (`cyclonedds.xml`), баннер при входе, цветной терминал с меткой `[docker:humble]` в начале приглашения, цветные логи нод, автодополнение `ros2` и `colcon`, `dds-check` и набор утилит для отладки сети, пользователь `ros` с `sudo`, рабочее пространство `/home/ros/developer_ws` (монтируется с хоста). Всё, что уходит в контейнер, лежит в папке `user_data/` образа и монтируется в домашний каталог `/home/ros`. Настройки в `user_data/ros2_custom_config_setup/` правятся без пересборки.

## Структура репозитория

```
.
├── ros2-base-humble-arm64/
├── ros2-base-humble-amd64/
└── ros2-base-humble-jetson/
    ├── Dockerfile
    ├── .env                         # VERSION образа, HOST_UID/HOST_GID для compose
    ├── CHANGELOG.md                 # подробная история версий
    ├── docker-compose.yml           # один сервис, имя = имя образа
    ├── build_image.sh               # сборка
    ├── start_container.sh           # разовый запуск без compose
    ├── set_host_ids.sh              # пишет HOST_UID/HOST_GID в .env
    ├── save_image.sh / load_image.sh
    ├── ros_entrypoint.sh            # вшивается в образ при сборке, не редактировать
    └── user_data/                   # каждый элемент монтируется в /home/ros
        ├── developer_ws/            # рабочее пространство, свой src/ кладётся сюда
        ├── extra_files_to_container/  # произвольные файлы, дампы и т. п.
        └── ros2_custom_config_setup/  # правится без пересборки
            ├── setup.sh             # окружение ROS и DDS
            ├── bashrc.sh            # терминал: автодополнение, метка в prompt, баннер
            ├── banner.sh            # баннер при входе (и сообщение от организаторов)
            ├── dds_check.sh         # диагностика сети и DDS, в контейнере: dds-check
            └── cyclonedds.xml       # конфиг CycloneDDS 0.10
```

## Подготовка Jetson

Делается один раз на каждом Jetson, на котором собираются или запускаются образы.

### Docker и nvidia-рантайм

Нужен рантайм `nvidia` в `/etc/docker/daemon.json` (на JetPack 4 он обычно уже есть, но по умолчанию не выбран):

```bash
sudo tee /etc/docker/daemon.json <<'EOF'
{
    "runtimes": {
        "nvidia": {
            "path": "nvidia-container-runtime",
            "runtimeArgs": []
        }
    },
    "default-runtime": "nvidia",
    "dns": ["8.8.8.8", "1.1.1.1"]
}
EOF
sudo systemctl restart docker
```

Если реестр, из которого ты тянешь образы, работает без TLS, добавь в тот же файл `"insecure-registries": ["<адрес-реестра>:5000"]`.

### Docker Compose

На JetPack 4 плагина Compose v2 обычно нет. Ставится одним бинарником:

```bash
mkdir -p ~/.docker/cli-plugins
curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-aarch64 \
  -o ~/.docker/cli-plugins/docker-compose
chmod +x ~/.docker/cli-plugins/docker-compose
docker compose version
```

Если запускаешь Docker через `sudo`, положи плагин в `/usr/local/lib/docker/cli-plugins/` вместо `~/.docker/cli-plugins/`.

Compose используется только для запуска. Собирать образы надёжнее скриптом `build_image.sh` (см. ниже): новым версиям Compose для сборки нужен свежий плагин Buildx, которого на JetPack 4 тоже нет.

### Swap

Сборка на Nano с 4 ГБ памяти (ROS из исходников в образе `ros2-base-humble-jetson`; OpenCV в образе из репозитория go1-hackathon-images) может упасть из-за нехватки памяти. Перед сборкой стоит добавить swap:

```bash
sudo fallocate -l 4G /swapfile && sudo chmod 600 /swapfile
sudo mkswap /swapfile && sudo swapon /swapfile
```

### Ядро под видео

Чтобы большие сообщения (кадры видео) не терялись, увеличь буферы сокетов и параметры сборки фрагментов. Это настраивается на хосте Jetson, а не в контейнере:

```bash
sudo tee /etc/sysctl.d/60-ros2-dds.conf > /dev/null <<'EOF'
net.core.rmem_max=2147483647
net.core.wmem_max=2147483647
net.ipv4.ipfrag_time=3
net.ipv4.ipfrag_high_thresh=134217728
EOF
sudo sysctl --system
```

После этого в `user_data/ros2_custom_config_setup/cyclonedds.xml` можно раскомментировать блок `<SocketReceiveBufferSize min="10MB"/>`. Те же настройки нужны и на ноутбуках, которые принимают видео.

## Сборка образов

Каждый образ собирается скриптом `build_image.sh` из своей папки:

```bash
cd ros2-base-humble-arm64 && ./build_image.sh           # на arm64-машине
cd ros2-base-humble-amd64 && ./build_image.sh
cd ros2-base-humble-jetson && ./build_image.sh          # на Jetson Nano
```


UID и GID пользователя на сборку не влияют: образ универсальный, их подгоняет entrypoint при запуске (см. «Пользователь»). Для сборки нужен интернет: CycloneDDS и пакеты скачиваются с GitHub и из apt, а базовые образы `ros:humble-ros-base-jammy` и `dustynv/ros` берутся с Docker Hub. Если он у тебя недоступен, скачай их заранее и положи в свой реестр (`docker pull`, `docker tag`, `docker push`), а в `FROM` Dockerfile подставь адрес своего реестра.


## Публикация в реестр

Версия берётся из `.env` образа (`VERSION`). Выпуск новой версии:

1. Поменять `VERSION` в `.env` и добавить запись в `CHANGELOG.md`.
2. Обновить версию в таблице в начале этого README.
3. Собрать и отправить образ:

```bash
cd ros2-base-humble-jetson
./build_image.sh
source .env && docker push registry.cookcloud.ru/base_images/ros2-base-humble-jetson:$VERSION
```

Разовая сборка другой версии без правки `.env`: `VERSION=v1.0.1 ./build_image.sh`. Extra-репозитории указывают базу в `FROM` полным адресом, например `FROM registry.cookcloud.ru/base_images/ros2-base-humble-jetson:v1.0.0`.

## Перенос образов на другие устройства

Собирать образ на каждом устройстве не нужно: соберите один раз и разнесите файлом. В папке нужного образа:

```bash
./save_image.sh     # создаёт ros2-base-humble-<вариант>-<версия>.tar
# скопировать .tar на другое устройство (scp, флешка), туда же положить папку образа
./load_image.sh     # загружает образ из .tar
```

Extra-образам из репозиториев go1-hackathon-images и jetbot-images базовый образ нужен только при сборке; для запуска достаточно их собственного образа. Файлы `.tar` исключены из контекста сборки (`.dockerignore`) и из git (`.gitignore`).

## Запуск

Все команды выполняются из папки нужного образа (например, `cd ros2-base-humble-jetson`).

Один раз на машину запиши свои UID/GID в `.env`, чтобы файлы из контейнера принадлежали тебе, а не root: `./set_host_ids.sh`. Без этого compose использует 1000.

| Действие | Команда |
|---|---|
| Запустить контейнер в фоне | `docker compose up -d` |
| Зайти в контейнер | `docker compose exec -u ros <имя образа> bash` (например, `ros2-base-humble-jetson`) |
| Зайти без compose | `docker exec -it -u ros <имя образа> bash` |
| Зайти под root | `docker compose exec <имя образа> bash` |
| Посмотреть, запущен ли контейнер | `docker compose ps` |
| Остановить и удалить контейнер | `docker compose down` |
| Разовый запуск без compose | `./start_container.sh` |

Контейнеры запускаются с `restart: unless-stopped`: после перезагрузки хоста контейнер поднимается сам, если его не остановили вручную. Контейнеры разных образов называются по-разному (по имени образа), но работают с `network_mode: host` и одним набором портов DDS, поэтому одновременно держи запущенным один.

Образы `ros2-base-humble-arm64` и `ros2-base-humble-amd64` запускаются без nvidia-рантайма и работают на любом хосте нужной архитектуры. На хосте с nvidia-рантаймом (Jetson с JetPack 6, GPU-сервер) раскомментируй в `docker-compose.yml` строку `runtime: nvidia` (в `start_container.sh` добавь `--runtime nvidia`). CUDA в эти образы не входит, её библиотеки подставляет рантайм.

### Что монтируется

| В папке образа | В контейнере |
|---|---|
| `user_data/developer_ws/` | `/home/ros/developer_ws` |
| `user_data/extra_files_to_container/` | `/home/ros/extra_files_to_container` |
| `user_data/ros2_custom_config_setup/` | `/home/ros/ros2_custom_config_setup` |
| `/dev` (хост) | `/dev` (камеры и USB, вместе с `privileged`) |

Контейнер работает с `network_mode: host`, поэтому ноды в нём видны ноутбуку и другим машинам в сети без проброса портов.

## Терминал и пользователь

### Пользователь

Внутри контейнера работает пользователь `ros` с `sudo` без пароля. Образ универсальный: контейнер стартует от root, entrypoint подгоняет UID/GID пользователя `ros` под `HOST_UID`/`HOST_GID` (их передают `docker-compose.yml` и `start_container.sh`), чинит владельца `/home/ros` и `/home/ros/developer_ws` (кроме примонтированного `src/`) и переходит на `ros`. Поэтому файлы в `src/` принадлежат тебе на хосте, а один и тот же образ работает на машинах с любым UID. Без `HOST_UID` остаются UID/GID из образа (1000), `HOST_UID=0` оставляет root.

Пользователь состоит в группах `video`, `dialout` и `plugdev`. Кроме того, entrypoint добавляет его в группы, которым на хосте принадлежат `/dev/video*`, `/dev/ttyUSB*` и `/dev/ttyACM*`, поэтому камеры и serial доступны, даже если GID групп на хосте другие.

`docker exec` не проходит через entrypoint и по умолчанию заходит под root, поэтому для входа под `ros` нужен `-u ros` (см. «Запуск»). Если нужен root: `sudo -i` внутри контейнера или вход без `-u`.

Extra-образы, построенные на этих базах, наследуют entrypoint. Если в extra-образе задан свой `ENTRYPOINT`, он должен вызывать `/ros2_custom_entrypoint.sh "$@"`, иначе подгонки UID не будет. Инструкции `USER root` / `USER ros` в их Dockerfile больше не нужны: сборка идёт от root.

Учти, что контейнер запущен с `privileged` и примонтированным `/dev`, а у пользователя есть `sudo`. Это значит, что изнутри контейнера можно получить права root на самом Jetson. Отдельный профиль `student` без `sudo` на хосте от этого не защищает: изоляция на уровне контейнера здесь условная, и это нормально для учебного стенда, где Jetson не жалко перепрошить.

### Что настроено в терминале

- **Метка в prompt:** `[docker:humble] ros@jetson:/home/ros/developer_ws$`. Из-за `network_mode: host` у контейнера тот же hostname, что у Jetson, и без метки легко перепутать, где ты находишься.
- **Баннер при входе:** версия ROS, реализация DDS и версия CycloneDDS, `ROS_DOMAIN_ID`, найден ли конфиг DDS (зелёный путь или красное «файл не найден») и собрано ли рабочее пространство.
- **Сообщение от организаторов:** если заполнить переменную `MESSAGE` в начале `user_data/ros2_custom_config_setup/banner.sh`, оно будет выводиться под баннером. Удобно для пароля Wi-Fi, канала помощи или правил.
- **Автодополнение по Tab** для bash, `ros2` (команды, пакеты, топики, ноды) и `colcon`.
- **Цветные логи нод** по уровню (WARN жёлтым, ERROR красным), в том числе при `ros2 launch`: `RCUTILS_COLORIZED_OUTPUT=1` в `setup.sh`.
- **nano** с подсветкой синтаксиса и номерами строк.

Всё, кроме подсветки в nano и цветного prompt, задаётся в `bashrc.sh`, `banner.sh` и `setup.sh` на хосте. Правки применяются в новых терминалах без пересборки образа.

## Окружение и DDS

При старте контейнера (через entrypoint) и в каждом новом терминале (через `bashrc.sh`) подключается `user_data/ros2_custom_config_setup/setup.sh`. У каждого образа свой экземпляр `setup.sh` (в его папке), устроены они одинаково. Он сам определяет, какой ROS в контейнере:

1. Окружение ROS: `/opt/ros/<distro>/install/setup.bash`.
2. CycloneDDS 0.10 из `/opt/cyclonedds_ws`, если он собирался отдельно (в образе `ros2-base-humble-jetson` только если его не было в базовом образе dustynv/ros; в образах `ros2-base-humble-arm64` и `ros2-base-humble-amd64` CycloneDDS штатный и этого шага нет).
3. `RCUTILS_COLORIZED_OUTPUT=1`, `RMW_IMPLEMENTATION=rmw_cyclonedds_cpp` и `CYCLONEDDS_URI` на `cyclonedds.xml`, если файл есть.
4. Рабочее пространство `/home/ros/developer_ws/install/setup.bash`, если оно уже собрано.

`setup.sh` лежит на хосте, поэтому его можно править без пересборки образа. Изменения применяются в новых терминалах (`docker compose exec ...`), а для entrypoint — после перезапуска контейнера.

### Конфиг CycloneDDS

У каждого образа свой `user_data/ros2_custom_config_setup/cyclonedds.xml`; по умолчанию они одинаковые, и в каждом стоит CycloneDDS 0.10, так что править можно независимо. По умолчанию CycloneDDS сам выбирает интерфейс. В файле есть закомментированные примеры: явный выбор интерфейсов (например, `l4tbr0` для USB-сети с ноутбуком), большой буфер приёма для видео, обнаружение по unicast и отладочный вывод. Изменения применяются при следующем запуске ноды. После правки выполни `ros2 daemon stop`, чтобы демон тоже перечитал конфиг.

Если файл удалить или переименовать, CycloneDDS будет работать с настройками по умолчанию.

### Совместимость между образами

Во всех образах семейства (включая extra-образы из репозиториев go1-hackathon-images и jetbot-images) Humble и CycloneDDS 0.10, поэтому ноды из любых образов и с ноутбука на Ubuntu 22.04 видят друг друга без оговорок.
## Отладка сети и DDS

### `dds-check`: быстрая диагностика

Первое, что стоит выполнить, если ноды не видят друг друга или видео тормозит:

```bash
dds-check
```

За пару секунд команда проверяет и показывает с пометками OK, WARN и FAIL:

- окружение ROS: реализацию DDS, `ROS_DOMAIN_ID` и не включён ли `ROS_LOCALHOST_ONLY`;
- конфиг CycloneDDS: найден ли файл, нет ли ошибок в XML и не попал ли туда синтаксис версии 0.7;
- сетевые интерфейсы: какие включены, у каких есть линк и поддерживают ли они мультикаст;
- маршрут для мультикаста DDS (`239.255.0.1`);
- буферы ядра для больших сообщений (видео);
- открытые сокеты DDS в диапазоне портов текущего домена;
- состояние демона `ros2`, включая случай, когда он завис.

В конце команда подсказывает, какими утилитами копать дальше. Сам скрипт лежит на хосте в `user_data/ros2_custom_config_setup/dds_check.sh` (в папке образа), его можно дорабатывать без пересборки образа. Без `sudo` в разделе про сокеты не видно имён процессов; с ними: `sudo bash /home/ros/ros2_custom_config_setup/dds_check.sh`.

### Утилиты в образе

| Задача | Утилиты |
|---|---|
| Интерфейсы, адреса, маршруты, сокеты | `ip`, `ss`, `ifconfig`, `netstat` |
| Связность | `ping`, `traceroute`, `nc`, `socat`, `dig`, `curl` |
| Wi-Fi и кабель | `iw`, `iwconfig`, `ethtool` |
| Запись трафика | `tcpdump` (нужен `sudo`) |
| Пропускная способность и потери | `iperf3` |
| Загрузка интерфейсов вживую | `nload`, `iftop` (нужен `sudo`) |
| Процессы, порты, устройства | `lsof`, `fuser`, `strace`, `htop` |
| Проверка XML-конфига | `xmllint` |
| Чистый DDS без ROS | `ddsperf` |
| ROS2 | `ros2 multicast`, `ros2 doctor`, `ros2 daemon` |

`ddsperf` берётся из окружения ROS (в образах `ros2-base-humble-arm64` и `ros2-base-humble-amd64` он идёт в пакете `ros-humble-cyclonedds`), а если его там нет, при сборке образа CycloneDDS 0.10 собирается отдельно только ради `ddsperf` в `/opt/cyclonedds_tools`, не трогая CycloneDDS, с которым работает ROS.

`ros2 multicast` и `ros2 doctor` входят в стандартный набор `ros2cli`. Если в базовом образе jetson-containers их не окажется, команда сообщит, что такой подкоманды нет.

### Типичные сценарии

Ниже «здесь» — контейнер на Jetson, «там» — ноутбук или другой Jetson. Для проверок с двух сторон нужен ROS2 (или этот же образ) и на второй машине.

**Ноды не видят друг друга между машинами.** Сначала проверь, проходит ли мультикаст, на котором держится обнаружение нод:

```bash
ros2 multicast receive        # здесь
ros2 multicast send           # там
```

Если сообщение дошло, мультикаст работает, и дальше стоит смотреть `ROS_DOMAIN_ID`, реализацию DDS и конфиг. Если не дошло, его режет сеть (часто так бывает с Wi-Fi роутерами, VPN или фаерволом). Тогда либо настрой сеть, либо включи обнаружение по unicast через блок `<Peers>` в `cyclonedds.xml`.

**Сколько реально пролезает по Wi-Fi.** Видео упирается в канал, поэтому полезно знать его реальную ёмкость и потери на UDP:

```bash
iperf3 -s                                  # здесь
iperf3 -c <IP Jetson> -u -b 100M -t 10     # там: UDP, 100 Мбит/с, 10 секунд
```

В итогах смотри на `Lost/Total Datagrams`: если при нужной тебе скорости потери выше нескольких процентов, сырое видео по этому каналу не пройдёт, нужно сжатие. Варьируй `-b`, чтобы найти потолок.

**То же на уровне DDS, без ROS.** Показывает, сколько выдаёт сам CycloneDDS по этой сети:

```bash
ddsperf sub                    # здесь
ddsperf pub size 1MB           # там
```

Обе стороны должны использовать CycloneDDS. Полный список режимов: `ddsperf help`.

**Сколько трафика уходит прямо сейчас.** Удобно включить во время работы драйвера камеры:

```bash
nload wlan0
```

**Качество Wi-Fi-соединения:** уровень сигнала и текущая скорость канала.

```bash
iw dev wlan0 link
```

**Запись трафика DDS для разбора в Wireshark.** Файл сохраняется в примонтированную папку и сразу появляется на хосте:

```bash
sudo tcpdump -i wlan0 -n udp portrange 7400-7649 -w /home/ros/extra_files_to_container/dds.pcap
```

Диапазон портов `7400-7649` соответствует домену 0, для домена `D` это `7400+250·D` … `7649+250·D`. Остановить запись: `Ctrl+C`. Потом скопируй `user_data/extra_files_to_container/dds.pcap` на ноутбук и открой в Wireshark: он сам распознаёт протокол RTPS, на котором работает DDS.

**Кто держит камеру или порт.**

```bash
sudo fuser -v /dev/video*
sudo ss -uanp | grep 74
```

## Частые проблемы

**Сборка падает с `Killed` или `internal compiler error`.** Не хватило памяти. Добавь swap (см. «Подготовка Jetson»). Если не помогает, уменьши число потоков сборки в Dockerfile образа `ros2-base-humble-jetson`.

**Сборка зависает на «Sending build context to Docker daemon».** В папке проекта лежит что-то большое, не указанное в `.dockerignore`. Обычно это сохранённые образы с нестандартным именем: переименуй их в `*.tar` или вынеси из папки.

**`docker compose up -d` ничего не запускает.** Проверь, что команда запущена из папки образа (там лежит `docker-compose.yml`).

**`unknown or invalid runtime name: nvidia`.** На этом Jetson не настроен nvidia-рантайм (см. «Docker и nvidia-рантайм» в разделе «Подготовка Jetson»).

**Нода на CycloneDDS не запускается с ошибкой `failed to increase socket receive buffer size`.** В `cyclonedds.xml` включён `<SocketReceiveBufferSize>`, а ядро Jetson не настроено. Выполни настройку из раздела «Ядро под видео» или закомментируй этот блок обратно.

**При входе нет баннера и метки `[docker:...]`, не работает автодополнение.** Не примонтирована папка `user_data/ros2_custom_config_setup` (контейнер запущен не через compose или из другой папки) или в ней нет `bashrc.sh`. Проверь: `ls /home/ros/ros2_custom_config_setup` внутри контейнера.

**Файлы в `user_data/developer_ws/` на хосте принадлежат не тому пользователю.** Контейнер запущен без `HOST_UID`/`HOST_GID`. Выполни `./set_host_ids.sh` и перезапусти контейнер (`docker compose up -d --force-recreate`). Уже созданные файлы можно вернуть себе: `sudo chown -R $USER:$USER user_data/developer_ws`.

**Непонятно, почему ноды не видят друг друга.** Начни с `dds-check`, а дальше по сценариям из раздела «Отладка сети и DDS».

**`ros2 topic list` зависает.** Демон `ros2` запущен со старыми настройками или завис. Выполни `ros2 daemon stop` или используй `ros2 topic list --no-daemon`.
