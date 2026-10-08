#!/usr/bin/env bash
# --- This file can be edited. ---
# Быстрая диагностика сети и DDS. В контейнере вызывается командой: dds-check
# Проверяет то, из-за чего ноды чаще всего не видят друг друга или теряют видео.
# Права root не нужны (без sudo в разделе про сокеты не будут видны имена процессов).

G='\033[0;32m'; Y='\033[0;33m'; R='\033[0;31m'; B='\033[1m'; N='\033[0m'
ok()   { echo -e "  ${G}OK${N}    $*"; }
warn() { echo -e "  ${Y}WARN${N}  $*"; }
bad()  { echo -e "  ${R}FAIL${N}  $*"; }
info() { echo -e "        $*"; }
hdr()  { echo -e "\n${B}== $* ==${N}"; }

domain="${ROS_DOMAIN_ID:-0}"

# ---------------------------------------------------------------------------
hdr "Окружение ROS"
info "ROS_DISTRO=${ROS_DISTRO:-не задан}  RMW_IMPLEMENTATION=${RMW_IMPLEMENTATION:-по умолчанию}  ROS_DOMAIN_ID=${domain}"
if [ "${RMW_IMPLEMENTATION}" = "rmw_cyclonedds_cpp" ]; then
    ok "используется CycloneDDS"
else
    warn "RMW_IMPLEMENTATION не rmw_cyclonedds_cpp: на других машинах должна быть та же реализация"
fi
if [ "${ROS_LOCALHOST_ONLY:-0}" = "1" ]; then
    warn "ROS_LOCALHOST_ONLY=1: ноды видны только на этой машине"
fi

# ---------------------------------------------------------------------------
hdr "Конфиг CycloneDDS"
if [ -z "${CYCLONEDDS_URI}" ]; then
    warn "CYCLONEDDS_URI не задан, CycloneDDS работает с настройками по умолчанию"
else
    case "${CYCLONEDDS_URI}" in
        "<"*) ok "конфиг задан прямо в переменной (XML внутри CYCLONEDDS_URI)" ;;
        *)
            cfg="${CYCLONEDDS_URI#file://}"
            if [ ! -f "${cfg}" ]; then
                bad "файл не найден: ${cfg}"
            elif command -v xmllint > /dev/null && ! xmllint --noout "${cfg}" 2> /dev/null; then
                bad "в XML ошибка: ${cfg}"
                info "подробности: xmllint --noout ${cfg}"
            else
                ok "${cfg}"
                if grep -q "<NetworkInterfaceAddress>" "${cfg}"; then
                    warn "в конфиге <NetworkInterfaceAddress> — синтаксис CycloneDDS 0.7, для 0.10 используй <Interfaces>"
                fi
            fi
            ;;
    esac
fi

# ---------------------------------------------------------------------------
hdr "Сетевые интерфейсы"
ip -br addr | sed 's/^/        /'
echo
while IFS= read -r line; do
    name=$(echo "${line}" | awk -F': ' '{print $2}'); name="${name%@*}"
    flags=$(echo "${line}" | grep -o '<[^>]*>')
    [ "${name}" = "lo" ] && continue
    # флаги сравниваем целиком: UP — интерфейс включён, LOWER_UP — есть линк (кабель, Wi-Fi)
    flags=",${flags#<}"; flags="${flags%>},"
    case "${flags}" in *",UP,"*) up=1 ;; *) up=0 ;; esac
    case "${flags}" in *",LOWER_UP,"*) link=1 ;; *) link=0 ;; esac
    case "${flags}" in *",MULTICAST,"*) mc=1 ;; *) mc=0 ;; esac
    if [ "${up}" = 0 ]; then
        info "${name}: выключен"
    elif [ "${link}" = 0 ]; then
        info "${name}: включён, но нет линка (кабель не подключён или Wi-Fi не подключён к сети)"
    elif [ "${mc}" = 1 ]; then
        ok "${name}: включён, мультикаст поддерживается"
    else
        warn "${name}: включён, но без мультикаста (CycloneDDS не найдёт через него ноды без <Peers>)"
    fi
done < <(ip -o link)

# ---------------------------------------------------------------------------
hdr "Маршрут для мультикаста DDS (239.255.0.1)"
if route=$(ip route get 239.255.0.1 2> /dev/null); then
    ok "$(echo "${route}" | head -n1)"
    info "это маршрут ядра; интерфейс, который выбрал CycloneDDS, покажет блок <Tracing> в конфиге"
else
    bad "маршрута нет: обычно значит, что нет ни одной сети с маршрутом по умолчанию"
    info "для работы без сети пропиши в cyclonedds.xml интерфейс lo и <Peers> с localhost"
fi

# ---------------------------------------------------------------------------
hdr "Буферы ядра (важно для видео)"
check_min() {   # имя, текущее, минимум, подсказка
    if [ "$2" -ge "$3" ] 2> /dev/null; then ok "$1 = $2"; else warn "$1 = $2 (рекомендуется не меньше $3) $4"; fi
}
check_max() {
    if [ "$2" -le "$3" ] 2> /dev/null; then ok "$1 = $2"; else warn "$1 = $2 (рекомендуется не больше $3) $4"; fi
}
check_min net.core.rmem_max         "$(cat /proc/sys/net/core/rmem_max)"         10485760
check_min net.core.wmem_max         "$(cat /proc/sys/net/core/wmem_max)"         10485760
check_max net.ipv4.ipfrag_time      "$(cat /proc/sys/net/ipv4/ipfrag_time)"      3
check_min net.ipv4.ipfrag_high_thresh "$(cat /proc/sys/net/ipv4/ipfrag_high_thresh)" 134217728
info "настраиваются на хосте Jetson, а не в контейнере (см. README, «Ядро под видео»)"

# ---------------------------------------------------------------------------
hdr "Сокеты DDS (UDP, домен ${domain})"
base=$((7400 + 250 * domain))
top=$((base + 249))
socks=$(ss -uanp 2> /dev/null | awk -v lo="${base}" -v hi="${top}" \
        'NR > 1 { n = split($4, a, ":"); p = a[n] + 0; if (p >= lo && p <= hi) print }')
if [ -n "${socks}" ]; then
    ok "открыто сокетов в диапазоне портов ${base}-${top}: $(echo "${socks}" | wc -l)"
    echo "${socks}" | sed 's/^/        /'
else
    info "в диапазоне портов ${base}-${top} никто не слушает: сейчас нет запущенных нод в этом домене"
fi

# ---------------------------------------------------------------------------
hdr "Демон ros2"
if command -v ros2 > /dev/null; then
    status=$(timeout 10 ros2 daemon status 2>&1)
    if [ $? -eq 124 ]; then
        bad "ros2 daemon status завис: перезапусти демон (ros2 daemon stop) или используй --no-daemon"
    else
        info "${status}"
    fi
else
    warn "команда ros2 не найдена: окружение ROS не подключено"
fi

# ---------------------------------------------------------------------------
hdr "Что дальше"
info "мультикаст между машинами:   ros2 multicast receive  (здесь)  /  ros2 multicast send  (там)"
info "чистый DDS:                  ddsperf sub  /  ddsperf pub size 1MB"
info "пропускная способность UDP:  iperf3 -s  (здесь)  /  iperf3 -c <IP> -u -b 100M  (там)"
info "загрузка интерфейса вживую:  nload <интерфейс>"
info "подробнее: README, раздел «Отладка сети и DDS»"
echo
