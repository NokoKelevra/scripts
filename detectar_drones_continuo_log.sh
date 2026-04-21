#!/bin/bash

# === CONFIG ===
DRONE_OUIS=("60:60:1F" "28:CD:C1" "90:3A:E6" "00:26:7E" "00:12:1C")
INTERFACE="$1"
CAPTURE_FILE="drone_scan"
LOG_FILE="detecciones_drones.csv"
LOG_SYS="drone_detector.log"
SLEEP_INTERVAL=15

declare -A seen_macs

# === LOGGING ===
log() {
    local level="$1"
    local msg="$2"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$ts] [$level] $msg" | tee -a "$LOG_SYS"
}

# === LIMPIEZA ===
limpiar() {
    log "INFO" "Señal de salida recibida, limpiando entorno..."

    if [ -n "$AIRDUMP_PID" ]; then
        kill "$AIRDUMP_PID" 2>/dev/null
        log "INFO" "airodump-ng detenido"
    fi

    if [ -n "$MONITOR_IFACE" ]; then
        airmon-ng stop "$MONITOR_IFACE" >> "$LOG_SYS" 2>&1
        log "INFO" "Modo monitor desactivado"
    fi

    log "INFO" "Restaurando servicios de red"

    systemctl list-unit-files | grep -q NetworkManager && \
        systemctl restart NetworkManager >> "$LOG_SYS" 2>&1 && \
        log "INFO" "NetworkManager reiniciado"

    systemctl list-unit-files | grep -q wpa_supplicant && \
        systemctl restart wpa_supplicant >> "$LOG_SYS" 2>&1 && \
        log "INFO" "wpa_supplicant reiniciado"

    systemctl list-unit-files | grep -q dhcpcd && \
        systemctl restart dhcpcd >> "$LOG_SYS" 2>&1 && \
        log "INFO" "dhcpcd reiniciado"

    log "INFO" "Sistema restaurado correctamente"
    exit 0
}

# === VALIDACIONES ===

if [[ $EUID -ne 0 ]]; then
    echo "[ERROR] Ejecutar como root"
    exit 1
fi

[ -z "$INTERFACE" ] && { echo "Uso: sudo $0 <iface>"; exit 1; }

command -v airodump-ng >/dev/null || { log "ERROR" "airodump-ng no instalado"; exit 1; }
command -v airmon-ng >/dev/null || { log "ERROR" "airmon-ng no instalado"; exit 1; }

trap limpiar SIGINT SIGTERM

log "INFO" "===== INICIO DETECTOR DE DRONES ====="

# === PREPARAR ENTORNO ===
log "INFO" "Matando procesos conflictivos"
airmon-ng check kill >> "$LOG_SYS" 2>&1

# === MODO MONITOR ===
log "INFO" "Activando modo monitor en $INTERFACE"

if ! airmon-ng start "$INTERFACE" >> "$LOG_SYS" 2>&1; then
    log "ERROR" "No se pudo activar modo monitor"
    exit 1
fi

sleep 2

MONITOR_IFACE=$(iw dev | awk '$1=="Interface"{print $2}' | grep -E "${INTERFACE}|mon" | tail -n1)

if [ -z "$MONITOR_IFACE" ]; then
    log "ERROR" "No se detecta interfaz monitor"
    exit 1
fi

log "INFO" "Interfaz monitor: $MONITOR_IFACE"
log "DEBUG" "Interfaz usada para captura: $MONITOR_IFACE"

# === TEST AIRODUMP (NO INTERACTIVO) ===
log "INFO" "Verificando airodump-ng (modo no interactivo)"

TEST_FILE="/tmp/test_airodump"

timeout 5 airodump-ng "$MONITOR_IFACE" \
    --write "$TEST_FILE" --output-format csv \
    >> "$LOG_SYS" 2>&1

if ls "$TEST_FILE"*.csv >/dev/null 2>&1; then
    log "INFO" "airodump-ng operativo"
    rm -f "$TEST_FILE"*
else
    log "ERROR" "airodump-ng no genera datos"
    exit 1
fi

# === CSV ===
if [ ! -f "$LOG_FILE" ]; then
    echo "Timestamp,MAC,SSID,Fabricante" > "$LOG_FILE"
fi

# === LANZAR AIRODUMP ===
airodump-ng "$MONITOR_IFACE" --write "$CAPTURE_FILE" --output-format csv \
    >> "$LOG_SYS" 2>&1 &

AIRDUMP_PID=$!
log "INFO" "airodump-ng lanzado PID=$AIRDUMP_PID"

fail_count=0
MAX_FAILS=5

# === LOOP ===
while true; do

    CSV_FILE=$(ls -t "$CAPTURE_FILE"*.csv 2>/dev/null | head -n1)

    if [ -f "$CSV_FILE" ]; then

        fail_count=0
        cp "$CSV_FILE" /tmp/tmp_scan.csv

        awk -F',' 'NR>2 && $1 ~ /([0-9A-F]{2}:){5}/' /tmp/tmp_scan.csv | while read -r line; do

            mac=$(echo "$line" | awk -F',' '{print $1}' | xargs)

            for oui in "${DRONE_OUIS[@]}"; do
                if [[ "$mac" == "$oui"* ]]; then

                    ssid=$(echo "$line" | awk -F',' '{print $14}' | xargs)
                    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

                    case "$oui" in
                        "60:60:1F"|"28:CD:C1") fabricante="DJI" ;;
                        "90:3A:E6"|"00:26:7E") fabricante="Parrot" ;;
                        "00:12:1C") fabricante="Ryze" ;;
                        *) fabricante="Desconocido" ;;
                    esac

                    log "INFO" "Detectado: $mac ($fabricante)"

                    if [[ -z "${seen_macs[$mac]}" ]]; then
                        echo "$timestamp,$mac,$ssid,$fabricante" >> "$LOG_FILE"
                        seen_macs[$mac]=1
                    fi
                fi
            done

        done

    else
        ((fail_count++))
        log "WARN" "CSV no generado ($fail_count/$MAX_FAILS)"

        if [ "$fail_count" -ge "$MAX_FAILS" ]; then
            log "ERROR" "Reiniciando interfaz por fallo persistente"

            kill "$AIRDUMP_PID" 2>/dev/null
            airmon-ng stop "$MONITOR_IFACE" >> "$LOG_SYS" 2>&1
            airmon-ng start "$INTERFACE" >> "$LOG_SYS" 2>&1

            sleep 2

            MONITOR_IFACE=$(iw dev | awk '$1=="Interface"{print $2}' | grep -E "${INTERFACE}|mon" | tail -n1)

            airodump-ng "$MONITOR_IFACE" --write "$CAPTURE_FILE" --output-format csv \
                >> "$LOG_SYS" 2>&1 &

            AIRDUMP_PID=$!
            fail_count=0
        fi
    fi

    sleep "$SLEEP_INTERVAL"
done