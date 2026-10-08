# ros2-base-images: базовые образы ROS2 Humble

Три базовых Docker-образа на ROS2 Humble. Они не привязаны к конкретному роботу: на них строятся extra-образы из соседних репозиториев, а ещё их можно использовать сами по себе на любом ПК и одноплатнике нужной архитектуры.

| Папка | Образ | Ubuntu | Железо | Что внутри |
|---|---|---|---|---|
| `base-humble-arm64` | `ros2:base-humble-arm64` | 22.04 | arm64 | ROS из apt |
| `base-humble-amd64` | `ros2:base-humble-amd64` | 22.04 | amd64 | ROS из apt |
| `base-humble-jetson` | `ros2:base-humble-jetson` | 18.04 | Jetson Nano (JetPack 4.6.x, L4T 32.7.1) | ROS собран из исходников, CUDA через nvidia-рантайм |

Имена образов. Главное имя базы: `ros2:base-humble-<вариант>`, от него строятся extra-образы. После сборки (`build_image.sh`) образ получает ещё и второе имя `unitree-hackathon:base-humble-<вариант>`: это тот же образ, место на диске он не занимает, а участникам хакатона удобно, что всё нужное лежит в одном репозитории `unitree-hackathon`. `save_image.sh` кладёт в `.tar` оба имени, `push_base_images.sh` отправляет в реестр оба.

Кто на чём строится (у дополнительных образов тег начинается с `extra-`, у базовых с `base-`):

| Репозиторий | Образ | Основан на |
|---|---|---|
| go1-hackathon-images | `unitree-hackathon:extra-humble-jetson-camera` | `ros2:base-humble-jetson` |
| jetbot-images | `jetbot:extra-humble-amd64-host` | `ros2:base-humble-amd64` |
| jetbot-images | `jetbot:extra-humble-arm64-robot` | `ros2:base-humble-arm64` |

Во всех образах семейства (и в extra-образах из других репозиториев) одинаково: CycloneDDS 0.10, свой конфиг DDS (`cyclonedds.xml`), баннер при входе, цветной терминал с меткой `[docker:humble]` в начале приглашения, цветные логи нод, автодополнение `ros2` и `colcon`, `dds-check` и набор утилит для отладки сети, пользователь `ros` с `sudo`, рабочее пространство `/developer_ws` (свой `src/` монтируется с хоста). Настройки каждого образа лежат в его папке, в `ros2_custom_config_setup/`, и правятся без пересборки.

## Структура репозитория

```
.
├── build_all.sh                     # сборка образов подряд (по архитектуре машины или по списку)
├── push_base_images.sh              # публикация базовых образов в реестр
├── base-humble-arm64/
├── base-humble-amd64/
├── base-humble-jetson/
│   ├── Dockerfile
│   ├── docker-compose.yml           # один сервис, имя = имя образа
│   ├── build_image.sh               # сборка
│   ├── start_container.sh           # разовый запуск без compose
│   ├── save_image.sh / load_image.sh
│   ├── src/                         # монтируется в /developer_ws/src
│   ├── files_to_container/          # монтируется в /files_to_container
│   └── ros2_custom_config_setup/    # монтируется в контейнер, правится без пересборки
│       ├── setup.sh                 # окружение ROS и DDS
│       ├── bashrc.sh                # терминал: автодополнение, метка в prompt, баннер
│       ├── banner.sh                # баннер при входе (и сообщение от организаторов)
│       ├── dds_check.sh             # диагностика сети и DDS, в контейнере: dds-check
│       ├── cyclonedds.xml           # конфиг CycloneDDS 0.10
│       └── ros_entrypoint.sh        # вшивается в образ, не редактировать
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

Если у тебя есть свой реестр без TLS (см. «Публикация в реестр»), добавь в тот же файл `"insecure-registries": ["registry.local:5000"]`.

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

Сборка на Nano с 4 ГБ памяти (ROS из исходников в образе `base-humble-jetson`; OpenCV в образе из репозитория go1-hackathon-images) может упасть из-за нехватки памяти. Перед сборкой стоит добавить swap:

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

После этого в `ros2_custom_config_setup/cyclonedds.xml` можно раскомментировать блок `<SocketReceiveBufferSize min="10MB"/>`. Те же настройки нужны и на ноутбуках, которые принимают видео.

## Сборка образов

Каждый образ собирается скриптом `build_image.sh` из своей папки:

```bash
./base-humble-arm64/build_image.sh           # на Jetson Nano
./base-humble-amd64/build_image.sh
./base-humble-jetson/build_image.sh          # на Jetson Nano
```


UID и GID пользователя в контейнере берутся от того, кто запускает скрипт (обычно 1000). Переопределить: `USER_UID=1001 USER_GID=1001 ./base-humble-arm64/build_image.sh`. Для сборки нужен интернет: CycloneDDS и пакеты скачиваются с GitHub и из apt, а базовые образы `ros:humble-ros-base-jammy` и `dustynv/ros` берутся с Docker Hub. Если он у тебя недоступен, скачай их заранее и положи в свой реестр (`docker pull`, `docker tag`, `docker push`), а в `FROM` Dockerfile подставь адрес своего реестра.


## Публикация в реестр

Extra-репозитории берут базовый образ либо локальный (собранный на той же машине или загруженный через `load_image.sh`), либо из реестра. Чтобы выложить базу в реестр:

```bash
./push_base_images.sh registry.local:5000            # отправит те из базовых образов, что есть на этой машине
./push_base_images.sh registry.local:5000 jetson     # или только выбранные
```

В реестр каждый образ уходит под двумя именами (слои хранятся один раз): `registry.local:5000/ros2:base-humble-jetson` и алиас для участников хакатона `registry.local:5000/unitree-hackathon:base-humble-jetson`. Свой реестр без TLS поднимается одной командой, но каждую машину, которая из него тянет или в него пишет, нужно внести в `insecure-registries` в `/etc/docker/daemon.json`:

```bash
docker run -d --restart=always -p 5000:5000 -v /srv/registry:/var/lib/registry --name registry registry:2
```

Дальше в extra-репозиториях достаточно `REGISTRY=registry.local:5000 ./build_image.sh`.

## Перенос образов на другие устройства

Собирать образ на каждом устройстве не нужно: соберите один раз и разнесите файлом. В папке нужного образа:

```bash
./save_image.sh     # создаёт ros2-<имя>.tar (в нём оба имени образа)
# скопировать .tar на другое устройство (scp, флешка), туда же положить папку образа
./load_image.sh     # загружает образ из .tar
```

Extra-образам из репозиториев go1-hackathon-images и jetbot-images базовый образ нужен только при сборке; для запуска достаточно их собственного образа. Файлы `.tar` исключены из контекста сборки (`.dockerignore`) и из git (`.gitignore`).

## Запуск

Все команды выполняются из папки нужного образа (например, `cd base-humble-jetson`).

| Действие | Команда |
|---|---|
| Запустить контейнер в фоне | `docker compose up -d` |
| Зайти в контейнер | `docker compose exec <имя образа> bash` (например, `base-humble-jetson`) |
| Зайти без compose | `docker exec -it ros2-<имя образа> bash` |
| Зайти под root | `docker compose exec -u root <имя образа> bash` |
| Посмотреть, запущен ли контейнер | `docker compose ps` |
| Остановить и удалить контейнер | `docker compose down` |
| Разовый запуск без compose | `./start_container.sh` |

Контейнеры запускаются с `restart: unless-stopped`: после перезагрузки хоста контейнер поднимается сам, если его не остановили вручную. Контейнеры разных образов называются по-разному (`ros2-<имя образа>`), но работают с `network_mode: host` и одним набором портов DDS, поэтому одновременно держи запущенным один.

Образы `base-humble-arm64` и 2 запускаются без nvidia-рантайма и работают на любом хосте нужной архитектуры. На хосте с nvidia-рантаймом (Jetson с JetPack 6, GPU-сервер) раскомментируй в `docker-compose.yml` строку `runtime: nvidia` (в `start_container.sh` добавь `--runtime nvidia`). CUDA в образы `base-humble-arm64` и 2 не входит, её библиотеки подставляет рантайм.

### Что монтируется

| В папке образа | В контейнере |
|---|---|
| `src/` | `/developer_ws/src` |
| `files_to_container/` | `/files_to_container` |
| `ros2_custom_config_setup/` | `/ros2_custom_config_setup` |
| `/dev` (хост) | `/dev` (камеры и USB, вместе с `privileged`) |

Контейнер работает с `network_mode: host`, поэтому ноды в нём видны ноутбуку и другим машинам в сети без проброса портов.

## Терминал и пользователь

### Пользователь

Внутри контейнера работает пользователь `ros` с `sudo` без пароля. Его UID и GID совпадают с пользователем Jetson, который собирал образ, поэтому файлы, созданные в примонтированном `src/`, принадлежат этому пользователю на хосте, а не root. Пользователь состоит в группах `video`, `dialout` и `plugdev`: это нужно для доступа к камерам, последовательным портам и USB-устройствам.

Если нужен root: `sudo -i` внутри контейнера или вход сразу под root через `docker compose exec -u root <имя образа> bash`.

Учти, что контейнер запущен с `privileged` и примонтированным `/dev`, а у пользователя есть `sudo`. Это значит, что изнутри контейнера можно получить права root на самом Jetson. Отдельный профиль `student` без `sudo` на хосте от этого не защищает: изоляция на уровне контейнера здесь условная, и это нормально для учебного стенда, где Jetson не жалко перепрошить.

### Что настроено в терминале

- **Метка в prompt:** `[docker:humble] ros@jetson:/developer_ws$`. Из-за `network_mode: host` у контейнера тот же hostname, что у Jetson, и без метки легко перепутать, где ты находишься.
- **Баннер при входе:** версия ROS, реализация DDS и версия CycloneDDS, `ROS_DOMAIN_ID`, найден ли конфиг DDS (зелёный путь или красное «файл не найден») и собрано ли рабочее пространство.
- **Сообщение от организаторов:** если заполнить переменную `MESSAGE` в начале `ros2_custom_config_setup/banner.sh`, оно будет выводиться под баннером. Удобно для пароля Wi-Fi, канала помощи или правил.
- **Автодополнение по Tab** для bash, `ros2` (команды, пакеты, топики, ноды) и `colcon`.
- **Цветные логи нод** по уровню (WARN жёлтым, ERROR красным), в том числе при `ros2 launch`: `RCUTILS_COLORIZED_OUTPUT=1` в `setup.sh`.
- **nano** с подсветкой синтаксиса и номерами строк.

Всё, кроме подсветки в nano и цветного prompt, задаётся в `bashrc.sh`, `banner.sh` и `setup.sh` на хосте. Правки применяются в новых терминалах без пересборки образа.

## Окружение и DDS

При старте контейнера (через entrypoint) и в каждом новом терминале (через `bashrc.sh`) подключается `ros2_custom_config_setup/setup.sh`. У каждого образа свой экземпляр `setup.sh` (в его папке), устроены они одинаково. Он сам определяет, какой ROS в контейнере:

1. Окружение ROS: `/opt/ros/<distro>/install/setup.bash`.
2. CycloneDDS 0.10 из `/opt/cyclonedds_ws`, если он собирался отдельно (в образе `base-humble-jetson` только если его не было в базовом образе dustynv/ros; в образах `base-humble-arm64` и `base-humble-amd64` CycloneDDS штатный и этого шага нет).
3. `RCUTILS_COLORIZED_OUTPUT=1`, `RMW_IMPLEMENTATION=rmw_cyclonedds_cpp` и `CYCLONEDDS_URI` на `cyclonedds.xml`, если файл есть.
4. Рабочее пространство `/developer_ws/install/setup.bash`, если оно уже собрано.

`setup.sh` лежит на хосте, поэтому его можно править без пересборки образа. Изменения применяются в новых терминалах (`docker compose exec ...`), а для entrypoint — после перезапуска контейнера.

### Конфиг CycloneDDS

У каждого образа свой `ros2_custom_config_setup/cyclonedds.xml`; по умолчанию они одинаковые, и в каждом стоит CycloneDDS 0.10, так что править можно независимо. По умолчанию CycloneDDS сам выбирает интерфейс. В файле есть закомментированные примеры: явный выбор интерфейсов (например, `l4tbr0` для USB-сети с ноутбуком), большой буфер приёма для видео, обнаружение по unicast и отладочный вывод. Изменения применяются при следующем запуске ноды. После правки выполни `ros2 daemon stop`, чтобы демон тоже перечитал конфиг.

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

В конце команда подсказывает, какими утилитами копать дальше. Сам скрипт лежит на хосте в `ros2_custom_config_setup/dds_check.sh` (в папке образа), его можно дорабатывать без пересборки образа. Без `sudo` в разделе про сокеты не видно имён процессов; с ними: `sudo bash /ros2_custom_config_setup/dds_check.sh`.

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

`ddsperf` берётся из окружения ROS (в образах `base-humble-arm64` и `base-humble-amd64` он идёт в пакете `ros-humble-cyclonedds`), а если его там нет, при сборке образа CycloneDDS 0.10 собирается отдельно только ради `ddsperf` в `/opt/cyclonedds_tools`, не трогая CycloneDDS, с которым работает ROS.

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
sudo tcpdump -i wlan0 -n udp portrange 7400-7649 -w /files_to_container/dds.pcap
```

Диапазон портов `7400-7649` соответствует домену 0, для домена `D` это `7400+250·D` … `7649+250·D`. Остановить запись: `Ctrl+C`. Потом скопируй `files_to_container/dds.pcap` на ноутбук и открой в Wireshark: он сам распознаёт протокол RTPS, на котором работает DDS.

**Кто держит камеру или порт.**

```bash
sudo fuser -v /dev/video*
sudo ss -uanp | grep 74
```

## Частые проблемы

**Сборка падает с `Killed` или `internal compiler error`.** Не хватило памяти. Добавь swap (см. «Подготовка Jetson»). Если не помогает, уменьши число потоков сборки в Dockerfile образа `base-humble-jetson`.

**Сборка зависает на «Sending build context to Docker daemon».** В папке проекта лежит что-то большое, не указанное в `.dockerignore`. Обычно это сохранённые образы с нестандартным именем: переименуй их в `*.tar` или вынеси из папки.

**`docker compose up -d` ничего не запускает.** Проверь, что команда запущена из папки образа (там лежит `docker-compose.yml`).

**`unknown or invalid runtime name: nvidia`.** На этом Jetson не настроен nvidia-рантайм (см. «Docker и nvidia-рантайм» в разделе «Подготовка Jetson»).

**Нода на CycloneDDS не запускается с ошибкой `failed to increase socket receive buffer size`.** В `cyclonedds.xml` включён `<SocketReceiveBufferSize>`, а ядро Jetson не настроено. Выполни настройку из раздела «Ядро под видео» или закомментируй этот блок обратно.

**При входе нет баннера и метки `[docker:...]`, не работает автодополнение.** Не примонтирована папка `ros2_custom_config_setup` (контейнер запущен не через compose или из другой папки) или в ней нет `bashrc.sh`. Проверь: `ls /ros2_custom_config_setup` внутри контейнера.

**Файлы в `src/` на хосте принадлежат не тому пользователю.** UID пользователя в образе не совпадает с владельцем папки на хосте. Пересобери базовые образы от имени нужного пользователя (extra-образы наследуют пользователя своей базы, их тоже придётся пересобрать) или с явным `USER_UID`/`USER_GID` (см. «Сборка образов»). Уже созданные файлы можно вернуть себе: `sudo chown -R $USER:$USER src`.

**Непонятно, почему ноды не видят друг друга.** Начни с `dds-check`, а дальше по сценариям из раздела «Отладка сети и DDS».

**`ros2 topic list` зависает.** Демон `ros2` запущен со старыми настройками или завис. Выполни `ros2 daemon stop` или используй `ros2 topic list --no-daemon`.
