# ============================================================================
#  ROS2 Humble на Ubuntu 18.04 (jetson_edition)  ·  ros2:base-humble-jetson
#  Оригинальный Jetson Nano, L4T 32.7.1 (JetPack 4.6.x). CUDA через nvidia-рантайм.
#  Под Ubuntu 18.04 бинарных пакетов Humble нет, ROS собран из исходников (jetson-containers).
#  DDS-конфиг, баннер, цветной терминал с меткой в prompt, утилиты отладки сети и DDS.
#  Сборка: ./build_image.sh   (или docker build -t ros2:base-humble-jetson .)
#  Образ extra-humble-jetson-camera (камера Unitree) строится на этом образе.
# ============================================================================

# === 1. Базовый образ ===
# Готовый образ из jetson-containers (ветка legacy!), под L4T 32.7.1 (JetPack 4.6.x) —
# это версия L4T оригинального Jetson Nano. Внутри ROS2 Humble, собранный из исходников:
# под Ubuntu 18.04 бинарных пакетов Humble не существует. OpenCV нужной
# версии (4.1.1, под ABI UnitreeCameraSDK) собираем сами ниже — на практике оказалось,
# что готового репозитория NVIDIA с версией 4.1.1 в этом образе нет.
FROM dustynv/ros:humble-ros-base-l4t-r32.7.1

# === 1а. Фикс просроченного GPG-ключа репозитория ROS2 (packages.ros.org) ===
# Известный, задокументированный инцидент OSRF: старый подписывающий ключ
# (EXPKEYSIG F42ED6FBAB17C654) истёк по сроку действия. Из-за этого ЛЮБОЙ
# apt-get update в базовом образе падает целиком с "repository is not signed",
# даже не добираясь до установки твоих пакетов. Это не связано с нашим
# Dockerfile — чинится один раз, здесь, до всех остальных apt-операций.
#
# Шаг 1: временно разрешаем apt пропустить проверку подписи — но только
# чтобы поставить curl/gnupg, а они идут из обычных Ubuntu-репозиториев
# (не из ROS), так что по сути ничего непроверенного не используем.
RUN apt-get update -o Acquire::AllowInsecureRepositories=true && \
    apt-get install -y --no-install-recommends curl gnupg

# Шаг 2: подтягиваем АКТУАЛЬНЫЙ ключ прямо из репозитория rosdistro на GitHub.
#
# Важно: раньше здесь был вариант через "curl | gpg | tee" — если curl внутри
# такого конвейера тихо не скачивает файл (сеть, редирект, что угодно),
# ошибка никак не всплывает в обычном /bin/sh, и получается ПУСТОЙ, но
# "успешно" созданный keyring-файл. Поэтому здесь всё через промежуточный
# файл и явные проверки: curl -f упадёт с ошибкой, если сервер вернёт что-то
# не то, а "ls -la" в конце покажет размер итогового файла в логе сборки.
#
# Куда класть: сначала проверили cat /etc/apt/sources.list.d/*.list — там
# явно прописан signed-by=/usr/share/keyrings/ros-archive-keyring.gpg.
# При явном signed-by apt смотрит ТОЛЬКО туда, /etc/apt/trusted.gpg.d
# для этой записи полностью игнорируется — поэтому кладём новый ключ
# именно по этому пути, перезатирая старый истёкший файл.
RUN curl -fsSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc -o /tmp/ros.asc && \
    rm -f /usr/share/keyrings/ros-archive-keyring.gpg && \
    gpg --batch --yes --dearmor -o /usr/share/keyrings/ros-archive-keyring.gpg /tmp/ros.asc && \
    rm -f /tmp/ros.asc && \
    ls -la /usr/share/keyrings/ros-archive-keyring.gpg

# Шаг 3: теперь обычный apt-get update должен проходить чисто, без флагов
RUN apt-get update

# === 2. Инструменты сборки ===
# git/cmake/build-essential/pkg-config — для colcon build участников и для сборки
# CycloneDDS ниже. Всё, что нужно только камере (OpenCV, UnitreeCameraSDK), живёт в образе extra-humble-jetson-camera.
RUN apt-get update && apt-get install -y --no-install-recommends \
    git cmake build-essential pkg-config \
    && rm -rf /var/lib/apt/lists/*

# === 4. Рабочая директория для будущего colcon-воркспейса ===
# Кода участников здесь намеренно НЕТ — это базовый тулбокс-образ, который
# организатор кейса собирает и раздаёт командам ДО того, как появится
# какой-либо код. Участники сами примонтируют свой src/ через bind-mount
# при запуске контейнера (см. quickstart) и соберут его внутри уже своим colcon build.
RUN mkdir -p /developer_ws/src
WORKDIR /developer_ws

# Немного dev-инструментов, которые понадобятся участникам внутри контейнера:
# nano/vim/colcon — писать и собирать код; v4l-utils — команда v4l2-ctl для
# диагностики /dev/videoX (список камер, поддерживаемые форматы). Это чисто
# runtime-утилита для отладки, а не зависимость сборки SDK — поэтому она здесь,
# а не в блоке выше.
RUN apt-get update && apt-get install -y --no-install-recommends \
    nano vim v4l-utils \
    python3-colcon-common-extensions \
    neovim ranger mc \
    && rm -rf /var/lib/apt/lists/*

# === 4а. CycloneDDS 0.10.x ===
# В Humble штатный CycloneDDS — уже 0.10.x.
# Но jetson-containers собирает ROS из исходников с ограниченным набором пакетов,
# и rmw_cyclonedds_cpp в базовом образе может не оказаться. Проверяем: если есть —
# ничего не делаем, если нет — собираем CycloneDDS 0.10.x и rmw_cyclonedds
# (ветка humble) в /opt/cyclonedds_ws.
RUN cmake_ver=$(cmake --version | head -n1 | awk '{print $3}') && \
    echo "CMake в образе: ${cmake_ver}" && \
    if [ "$(printf '%s\n' 3.16 "${cmake_ver}" | sort -V | head -n1)" != "3.16" ]; then \
        apt-get update && apt-get install -y --no-install-recommends python3-pip && \
        rm -rf /var/lib/apt/lists/* && \
        python3 -m pip install -U "pip<22" && \
        python3 -m pip install "cmake>=3.16,<3.28" && \
        hash -r && echo "CMake обновлён: $(cmake --version | head -n1)"; \
    fi

RUN if [ -d /opt/ros/humble/install/share/rmw_cyclonedds_cpp ]; then \
        echo "rmw_cyclonedds_cpp уже есть в базовом образе, отдельная сборка не нужна"; \
    else \
        echo "rmw_cyclonedds_cpp нет в базовом образе, собираю CycloneDDS 0.10.x" && \
        mkdir -p /opt/cyclonedds_ws/src && cd /opt/cyclonedds_ws/src && \
        git clone --depth 1 -b releases/0.10.x https://github.com/eclipse-cyclonedds/cyclonedds && \
        git clone --depth 1 -b humble https://github.com/ros2/rmw_cyclonedds && \
        cd /opt/cyclonedds_ws && \
        colcon build --packages-select cyclonedds \
            --cmake-args -DCMAKE_BUILD_TYPE=Release -DBUILD_DDSPERF=ON && \
        bash -c "source /opt/ros/humble/install/setup.bash && \
                 colcon build --packages-select rmw_cyclonedds_cpp \
                     --cmake-args -DCMAKE_BUILD_TYPE=Release" && \
        rm -rf build log; \
    fi

# === 5. Удобный терминал ===
# Отдельным шагом в конце, чтобы правки здесь не пересобирали OpenCV и CycloneDDS.
# sudo — для пользователя ниже; bash-completion и python3-argcomplete —
# автодополнение по Tab для bash, ros2 и colcon.
RUN apt-get update && apt-get install -y --no-install-recommends \
    sudo bash-completion python3-argcomplete \
    && rm -rf /var/lib/apt/lists/*

# Подсветка синтаксиса и номера строк в nano — для всех пользователей сразу
RUN echo 'include "/usr/share/nano/*.nanorc"' >> /etc/nanorc && \
    echo 'set linenumbers' >> /etc/nanorc

# === 5а. Утилиты для отладки сети и DDS ===
# Отдельным шагом, чтобы правки списка не пересобирали всё, что выше.
#   iproute2, iputils-ping, net-tools, traceroute — интерфейсы, маршруты, связность
#     (ip, ss, ping, ifconfig, netstat, traceroute)
#   iw, wireless-tools, ethtool — состояние Wi-Fi (сигнал, скорость) и кабеля
#   tcpdump — запись трафика DDS в .pcap для разбора в Wireshark на ноутбуке
#   iperf3 — пропускная способность и потери UDP между Jetson и ноутбуком
#   nload, iftop — живая загрузка интерфейсов (сколько реально уходит видео)
#   netcat-openbsd, socat, dnsutils, curl — проверка отдельных портов и адресов
#   lsof, psmisc (fuser), strace, htop — кто держит устройство или порт, что делает процесс
#   libxml2-utils (xmllint) — проверка конфига CycloneDDS на ошибки в XML
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    iproute2 iputils-ping net-tools traceroute \
    iw wireless-tools ethtool \
    tcpdump iperf3 nload iftop \
    netcat-openbsd socat dnsutils curl \
    lsof psmisc strace htop \
    libxml2-utils \
    && rm -rf /var/lib/apt/lists/*

# ddsperf — замеры пропускной способности и задержки на чистом DDS, без ROS.
# Если в ROS-окружении его нет (бывает, когда CycloneDDS взят из базового образа),
# собираем отдельную копию CycloneDDS 0.10 только ради ddsperf в /opt/cyclonedds_tools,
# не трогая CycloneDDS, с которым работает ROS. Обёртка в /usr/local/bin подставляет
# свою библиотеку, чтобы ddsperf не зависел от LD_LIBRARY_PATH окружения ROS.
RUN if bash -c "source /opt/ros/${ROS_DISTRO}/install/setup.bash && \
                if [ -f /opt/cyclonedds_ws/install/setup.bash ]; then source /opt/cyclonedds_ws/install/setup.bash; fi && \
                command -v ddsperf"; then \
        echo "ddsperf уже есть в окружении ROS, отдельная сборка не нужна"; \
    else \
        echo "ddsperf нет, собираю CycloneDDS 0.10.x отдельно ради него" && \
        git clone --depth 1 -b releases/0.10.x https://github.com/eclipse-cyclonedds/cyclonedds /tmp/cyclonedds && \
        mkdir /tmp/cyclonedds/build && cd /tmp/cyclonedds/build && \
        cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/opt/cyclonedds_tools \
              -DBUILD_DDSPERF=ON -DENABLE_SSL=NO -DENABLE_SECURITY=NO -DENABLE_SHM=NO .. && \
        make -j$(nproc) install && \
        cd / && rm -rf /tmp/cyclonedds && \
        printf '#!/bin/sh\nLD_LIBRARY_PATH=/opt/cyclonedds_tools/lib exec /opt/cyclonedds_tools/bin/ddsperf "$@"\n' \
            > /usr/local/bin/ddsperf && \
        chmod 755 /usr/local/bin/ddsperf; \
    fi

# === 6. Пользователь ===
# Обычный пользователь с sudo без пароля, чтобы файлы, которые участники создают
# в примонтированном src/, не были root-овыми на хосте Jetson. UID/GID по умолчанию 1000,
# как у первого пользователя Jetson; меняются аргументами сборки (см. build_image.sh).
# Группы video/dialout/plugdev — доступ к камерам (/dev/video*), последовательным портам
# и USB-устройствам: контейнер запущен с privileged, но права на файлы в /dev
# всё равно проверяются.
# Если пользователь с таким UID уже есть в базовом образе, он просто переименовывается.
ARG USERNAME=ros
ARG USER_UID=1000
ARG USER_GID=1000
RUN if ! getent group ${USER_GID} > /dev/null; then \
        groupadd --gid ${USER_GID} ${USERNAME}; \
    fi && \
    if getent passwd ${USER_UID} > /dev/null; then \
        old_user=$(getent passwd ${USER_UID} | cut -d: -f1) && \
        usermod -l ${USERNAME} -g ${USER_GID} -d /home/${USERNAME} -m -s /bin/bash "${old_user}"; \
    else \
        useradd --uid ${USER_UID} --gid ${USER_GID} -m -s /bin/bash ${USERNAME}; \
    fi && \
    for grp in video dialout plugdev; do \
        if getent group ${grp} > /dev/null; then usermod -aG ${grp} ${USERNAME}; fi; \
    done && \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} && \
    chmod 0440 /etc/sudoers.d/${USERNAME} && \
    chown -R ${USER_UID}:${USER_GID} /developer_ws && \
    id ${USERNAME}

# === 7. Entrypoint и bashrc ===
# Всё содержимое настроек терминала лежит в ros2_custom_config_setup/bashrc.sh
# на хосте (монтируется в контейнер), поэтому его можно менять без пересборки.
# Здесь в ~/.bashrc root и пользователя добавляется только его подключение.
# force_color_prompt — цветной prompt из стандартного .bashrc Ubuntu.
COPY ros2_custom_config_setup/ros_entrypoint.sh /ros2_custom_entrypoint.sh
RUN chmod +x /ros2_custom_entrypoint.sh && \
    for rc in /root/.bashrc /home/${USERNAME}/.bashrc; do \
        sed -i 's/^#force_color_prompt=yes/force_color_prompt=yes/' "${rc}" && \
        echo 'if [ -f /ros2_custom_config_setup/bashrc.sh ]; then source /ros2_custom_config_setup/bashrc.sh; fi' >> "${rc}"; \
    done

USER ${USERNAME}

ENTRYPOINT ["/ros2_custom_entrypoint.sh"]
CMD ["bash"]
