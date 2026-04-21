#!/bin/bash

DRONE_OUIS=("60:60:1F" "28:CD:C1" "90:3A:E6" "00:26:7E" "00:12:1C")
INTERFACE="$1"
CAPTURE_FILE="drone_scan"
LOG_FILE="detecciones_drones.csv"
LOG_SYS="drone_detector.log"
SLEEP_INTERVAL=15

declare -A seen_macs

log() {
    local level="$1"
    local msg="$2"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$ts] [$level] $msg" | tee -a "$LOG_SYS"
}

limpiar() {
    log "INFO" "Interrupción detectada, limpiando..."

    if [ -n "$AIRDUMP_PID" ]; then
        kill "$AIRDUMP_PID" 2>/dev/null
        log "INFO" "Proceso airodump-ng detenido"
    fi

    airmon-ng stop "$MONITOR_IFACE" >> "$LOG_SYS" 2>&1
    log "INFO" "Interfaz restaurada"

    rm -f "$CAPTURE_FILE"*.csv
    log "INFO" "Archivos temporales eliminados"

    exit 0
}

# === VALIDACIONES ===

[ -z "$INTERFACE" ] && { echo "Uso: sudo $0 <iface>"; exit 1; }

command -v airodump-ng >/dev/null || { log "ERROR" "airodump-ng no encontrado"; exit 1; }
command -v airmon-ng >/dev/null || { log "ERROR" "airmon-ng no encontrado"; exit 1; }

trap limpiar SIGINT

log "INFO" "Iniciando detector de drones"

# === MODO MONITOR ===

if ! airmon-ng start "$INTERFACE" >> "$LOG_SYS" 2>&1; then
    log "ERROR" "Fallo al activar modo monitor en $INTERFACE"
    exit 1
fi

MONITOR_IFACE=$(iw dev | awk '$1=="Interface"{print $2}' | grep "$INTERFACE")

log "INFO" "Interfaz en modo monitor: $MONITOR_IFACE"

# === LOG CSV ===

if [ ! -f "$LOG_FILE" ]; then
    echo "Timestamp,MAC,SSID,Fabricante" > "$LOG_FILE"
    log "INFO" "Archivo CSV creado"
fi

# === LANZAR AIRODUMP ===

airodump-ng "$MONITOR_IFACE" --write "$CAPTURE_FILE" --output-format csv \
    >> "$LOG_SYS" 2>&1 &

AIRDUMP_PID=$!
log "INFO" "airodump-ng iniciado (PID: $AIRDUMP_PID)"

# === LOOP PRINCIPAL ===

while true; do
    CSV_FILE=$(ls -t "$CAPTURE_FILE"*.csv 2>/dev/null | head -n1)

    if [ -f "$CSV_FILE" ]; then
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

                    log "INFO" "Detectado posible dron: $mac ($fabricante)"

                    if [[ -z "${seen_macs[$mac]}" ]]; then
                        echo "$timestamp,$mac,$ssid,$fabricante" >> "$LOG_FILE"
                        seen_macs[$mac]=1
                        log "INFO" "Guardado en CSV: $mac"
                    fi
                fi
            done
        done
    else
        log "WARN" "CSV aún no generado por airodump-ng"
    fi

    sleep "$SLEEP_INTERVAL"
done