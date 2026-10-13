# ROS2 Humble, Ubuntu 18.04 · registry.cookcloud.ru/base_images/ros2-base-humble-jetson
# Jetson Nano, L4T 32.7.1 (JetPack 4.6.x), CUDA через nvidia-рантайм.
# ROS собран из исходников (jetson-containers): бинарных пакетов Humble под 18.04 нет.
# Сборка: ./build_image.sh

# Образ из jetson-containers (ветка legacy) под L4T 32.7.1
FROM dustynv/ros:humble-ros-base-l4t-r32.7.1

# Фикс просроченного ключа репозитория ROS2 (OSRF): без него любой apt-get update падает.
# curl и gnupg ставим из Ubuntu-репозиториев, проверку подписи для этого отключаем временно.
RUN apt-get update -o Acquire::AllowInsecureRepositories=true && \
    apt-get install -y --no-install-recommends curl gnupg

# Ключ качаем через файл с проверкой (curl -f), а не конвейером: иначе тихая ошибка
# даёт пустой keyring. Кладём туда, куда указывает signed-by в источниках apt.
RUN curl -fsSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc -o /tmp/ros.asc && \
    rm -f /usr/share/keyrings/ros-archive-keyring.gpg && \
    gpg --batch --yes --dearmor -o /usr/share/keyrings/ros-archive-keyring.gpg /tmp/ros.asc && \
    rm -f /tmp/ros.asc && \
    ls -la /usr/share/keyrings/ros-archive-keyring.gpg

RUN apt-get update

# Инструменты сборки
RUN apt-get update && apt-get install -y --no-install-recommends \
    git cmake build-essential pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Dev-инструменты
RUN apt-get update && apt-get install -y --no-install-recommends \
    nano vim v4l-utils \
    python3-colcon-common-extensions \
    neovim ranger mc \
    && rm -rf /var/lib/apt/lists/*

# CycloneDDS 0.10.x: если rmw_cyclonedds_cpp нет в базовом образе, собираем в /opt/cyclonedds_ws.
# Сначала обновляем CMake, если он старее 3.16.
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

# Терминал; gosu нужен entrypoint для перехода с root на пользователя
RUN apt-get update && apt-get install -y --no-install-recommends \
    sudo gosu bash-completion python3-argcomplete \
    && rm -rf /var/lib/apt/lists/*

RUN echo 'include "/usr/share/nano/*.nanorc"' >> /etc/nanorc && \
    echo 'set linenumbers' >> /etc/nanorc

# Утилиты отладки сети и DDS
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    iproute2 iputils-ping net-tools traceroute \
    iw wireless-tools ethtool \
    tcpdump iperf3 nload iftop \
    netcat-openbsd socat dnsutils curl \
    lsof psmisc strace htop \
    libxml2-utils \
    && rm -rf /var/lib/apt/lists/*

# ddsperf: если его нет в ROS-окружении, собираем отдельную копию CycloneDDS в /opt/cyclonedds_tools
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

# Пользователь с sudo без пароля. UID/GID здесь по умолчанию 1000,
# при запуске entrypoint подгоняет их под HOST_UID/HOST_GID.
# Если пользователь с таким UID уже есть в базовом образе, он переименовывается.
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
    mkdir -p /home/${USERNAME}/developer_ws /home/${USERNAME}/extra_files_to_container \
             /home/${USERNAME}/ros2_custom_config_setup && \
    chown -R ${USER_UID}:${USER_GID} /home/${USERNAME} && \
    id ${USERNAME}

# Интерактивный root-шелл (docker exec ... bash) сам переключается на ros, чтобы файлы в
# примонтированных папках не становились root-овыми. Пропускается при KEEP_ROOT=1 и в sudo -i.
RUN echo 'if [ -t 0 ] && [ -z "${KEEP_ROOT:-}" ] && [ -z "${SUDO_USER:-}" ] && id ros >/dev/null 2>&1; then export HOME=/home/ros; exec gosu ros bash; fi' >> /root/.bashrc

# Entrypoint; настройки терминала подключаются из user_data/ros2_custom_config_setup/bashrc.sh
COPY ros_entrypoint.sh /ros2_custom_entrypoint.sh
RUN chmod +x /ros2_custom_entrypoint.sh && \
    for rc in /root/.bashrc /home/${USERNAME}/.bashrc; do \
        sed -i 's/^#force_color_prompt=yes/force_color_prompt=yes/' "${rc}" && \
        echo 'if [ -f /home/ros/ros2_custom_config_setup/bashrc.sh ]; then source /home/ros/ros2_custom_config_setup/bashrc.sh; fi' >> "${rc}"; \
    done

# Рабочее пространство (монтируется из user_data/developer_ws)
WORKDIR /home/${USERNAME}/developer_ws

# USER не задан намеренно: entrypoint стартует от root и сам переходит на ros
ENTRYPOINT ["/ros2_custom_entrypoint.sh"]
CMD ["bash"]
