# ROS2 Humble, Ubuntu 22.04 (arm64) · registry.cookcloud.ru/base_images/ros2-base-humble-arm64
# ROS из apt, CycloneDDS 0.10.x, DDS-конфиг, баннер, утилиты отладки сети.
# Сборка: ./build_image.sh

FROM --platform=linux/arm64 ros:humble-ros-base-jammy

ARG DEBIAN_FRONTEND=noninteractive

# Если apt-get update падает из-за просроченного ключа ROS, обновляем ключ и повторяем.
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

# CycloneDDS 0.10.x (штатный в Humble)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ros-humble-cyclonedds ros-humble-rmw-cyclonedds-cpp \
    && rm -rf /var/lib/apt/lists/*

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
