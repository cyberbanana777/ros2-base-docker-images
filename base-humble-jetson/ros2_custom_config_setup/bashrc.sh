
# --- This file can be edited. ---
# Настройки интерактивного терминала в контейнере. Подключается из ~/.bashrc
# (и у пользователя, и у root). Лежит на хосте, поэтому правки применяются
# в новых терминалах без пересборки образа.

# Окружение ROS и DDS
if [ -f /ros2_custom_config_setup/setup.sh ]; then
    source /ros2_custom_config_setup/setup.sh
fi

# Автодополнение по Tab: bash, colcon, ros2
if [ -f /etc/bash_completion ]; then
    source /etc/bash_completion
fi
if [ -f /usr/share/colcon_argcomplete/hook/colcon-argcomplete.bash ]; then
    source /usr/share/colcon_argcomplete/hook/colcon-argcomplete.bash
fi
# register-python-argcomplete3 есть в Ubuntu 18.04, в 22.04 он называется register-python-argcomplete
if command -v ros2 > /dev/null; then
    if command -v register-python-argcomplete3 > /dev/null; then
        eval "$(register-python-argcomplete3 ros2)"
    elif command -v register-python-argcomplete > /dev/null; then
        eval "$(register-python-argcomplete ros2)"
    fi
fi

# Диагностика сети и DDS одной командой
alias dds-check='bash /ros2_custom_config_setup/dds_check.sh'

# Метка в prompt, чтобы не перепутать контейнер с хостом Jetson:
#   [docker:humble] ros@jetson:/developer_ws$
# (проверка нужна, чтобы метка не задваивалась при повторном source ~/.bashrc)
case "${PS1}" in
    *"[docker:"*) ;;
    *) PS1="\[\033[1;35m\][docker:${ROS_DISTRO}]\[\033[0m\] ${PS1}" ;;
esac

# Баннер при входе
if [ -f /ros2_custom_config_setup/banner.sh ]; then
    bash /ros2_custom_config_setup/banner.sh
fi
