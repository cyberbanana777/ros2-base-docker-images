# ============================================================================
#  ROS2 Humble на Ubuntu 22.04 (amd64)  ·  ros2:base-humble-amd64
#  Бинарные пакеты ROS из apt, CycloneDDS 0.10.x (штатный), DDS-конфиг, баннер,
#  цветной терминал с меткой в prompt, утилиты отладки сети и DDS.
#  Сборка: ./build_image.sh   (или docker build -t ros2:base-humble-amd64 .)
#  Запуск без nvidia-рантайма работает на любом amd64-хосте.
# ============================================================================

# === 1. Базовый образ ===
# Официальный образ ROS: Ubuntu 22.04 (jammy), ros-humble-ros-base из apt.
# Платформа указана явно, чтобы образ был именно amd64 даже при сборке на другой машине
# (через QEMU/buildx).
FROM --platform=linux/amd64 ros:humble-ros-base-jammy

ARG DEBIAN_FRONTEND=noninteractive

# === 1а. Страховка от проблем с ключом репозитория ROS2 ===
# Если apt-get update проходит чисто (так и должно быть со свежим базовым образом),
# ничего не делаем. Если падает из-за подписи (старый базовый образ с просроченным
# ключом OSRF), кладём актуальный ключ из rosdistro во все keyring-файлы, которые
# упомянуты в signed-by у источников apt, и повторяем update.
RUN if ! apt-get update; then \
        echo "apt-get update не прошёл, обновляю ключ ROS" && \
        apt-get update -o Acquire::AllowInsecureRepositories=true && \
        apt-get install -y --no-install-recommends curl gnupg ca-certificates && \
        curl -fsSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc -o /tmp/ros.asc && \
        for kr in /usr/share/keyrings/ros-archive-keyring.gpg \
                  $(grep -rhoE 'signed-by=[^] ]+' /etc/apt/sources.list.d/ 2>/dev/null | cut -d= -f2); do \
            rm -f "$kr" && gpg --batch --yes --dearmor -o "$kr" /tmp/ros.asc && ls -la "$kr"; \
        done && \
        rm -f /tmp/ros.asc && apt-get update; \
    fi && rm -rf /var/lib/apt/lists/*

# === 2. Инструменты сборки ===
# git/cmake/build-essential/pkg-config нужны участникам для colcon build и, при
# необходимости, для сборки ddsperf (см. 5а).
RUN apt-get update && apt-get install -y --no-install-recommends \
    git cmake build-essential pkg-config \
    && rm -rf /var/lib/apt/lists/*

# === 4. Рабочая директория для будущего colcon-воркспейса ===
# Кода участников здесь намеренно НЕТ — это базовый тулбокс-образ.
# Участники сами примонтируют свой src/ через bind-mount при запуске контейнера
# и соберут его внутри своим colcon build.
RUN mkdir -p /developer_ws/src
WORKDIR /developer_ws

# Dev-инструменты для участников: nano/vim/colcon — писать и собирать код; v4l-utils —
# v4l2-ctl для диагностики /dev/videoX. 
RUN apt-get update && apt-get install -y --no-install-recommends \
    nano vim v4l-utils \
    python3-colcon-common-extensions \
    neovim ranger mc \
    && rm -rf /var/lib/apt/lists/*

# === 4а. CycloneDDS 0.10.x ===
# В Ubuntu 22.04 + Humble CycloneDDS штатный и уже версии 0.10.x — собирать из исходников
# не нужно. Явно ставим пакеты, чтобы не зависеть от того, что именно вошло в базовый образ.
RUN apt-get update && apt-get install -y --no-install-recommends \
    ros-humble-cyclonedds ros-humble-rmw-cyclonedds-cpp \
    && rm -rf /var/lib/apt/lists/*

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
# В пакете ros-humble-cyclonedds он обычно есть. Если в ROS-окружении его нет,
# собираем отдельную копию CycloneDDS 0.10 только ради ddsperf в /opt/cyclonedds_tools,
# не трогая CycloneDDS, с которым работает ROS. Обёртка в /usr/local/bin подставляет
# свою библиотеку, чтобы ddsperf не зависел от LD_LIBRARY_PATH окружения ROS.
RUN if bash -c "source /opt/ros/${ROS_DISTRO}/setup.bash && \
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
