#!/bin/bash

# !!!! DO NOT EDIT !!!!
set -e
[ -f /ros2_custom_config_setup/setup.sh ] && source /ros2_custom_config_setup/setup.sh
exec "$@"
