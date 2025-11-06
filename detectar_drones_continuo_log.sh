#!/bin/bash

# === CONFIGURACIÓN ===
DRONE_OUIS=("60:60:1F" "28:CD:C1" "90:3A:E6" "00:26:7E" "00:12:1C")
INTERFACE="$1"
CAPTURE_FILE="drone_scan"
LOG_FILE="detecciones_drones.csv"
SLEEP_INTERVAL=15  # segundos entre análisis

# === FUNCIÓN LIMPIEZA ===
limpiar() {
    echo -e "\n\n[*] Interrumpido. Restaurando interfaz..."
    airmon-ng stop "$MONITOR_IFACE" > /dev/null 2>&1
    rm -f "$CAPTURE_FILE"*.csv
    echo "[*] Interfaz restaurada. ¡Hasta luego, piloto de radiofrecuencia! 🚁"
    exit 0
}

# === COMPROBACIONES INICIALES ===
if [ -z "$INTERFACE" ]; then
    echo "Uso: sudo ./detectar_drones_continuo.sh <interfaz_wifi>"
    exit 1
fi

# === INICIO ===
trap limpiar SIGINT

echo "[*] Poniendo $INTERFACE en modo monitor..."
airmon-ng start "$INTERFACE" > /dev/null 2>&1
MONITOR_IFACE="${INTERFACE}mon"

# Crear archivo de log si no existe
if [ ! -f "$LOG_FILE" ]; then
    echo "Timestamp,MAC,SSID,Posible Fabricante" > "$LOG_FILE"
fi

echo "[*] Iniciando escaneo continuo (pulsa Ctrl+C para detener)..."

# Ejecutar airodump-ng en segundo plano
airodump-ng "$MONITOR_IFACE" --write "$CAPTURE_FILE" --output-format csv > /dev/null 2>&1 &

AIRDUMP_PID=$!

# Bucle infinito con análisis periódico
while true; do
    CSV_FILE=$(ls -t "$CAPTURE_FILE"*.csv 2>/dev/null | head -n1)

    if [ -f "$CSV_FILE" ]; then
        echo -e "\n🚁 [$(date +'%H:%M:%S')] Análisis de posibles drones detectados:\n"
        grep -v 'BSSID' "$CSV_FILE" | while IFS=',' read -r mac rest; do
            mac_trimmed=$(echo "$mac" | tr -d ' ')
            for oui in "${DRONE_OUIS[@]}"; do
                if [[ "$mac_trimmed" == "$oui"* ]]; then
                    ssid=$(echo "$rest" | cut -d',' -f 13 | tr -d ' ')
                    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

                    # Determinar posible fabricante
                    case "$oui" in
                        "60:60:1F"|"28:CD:C1") fabricante="DJI" ;;
                        "90:3A:E6"|"00:26:7E") fabricante="Parrot" ;;
                        "00:12:1C") fabricante="Ryze" ;;
                        *) fabricante="Desconocido" ;;
                    esac

                    echo "🔸 MAC: $mac_trimmed | SSID: $ssid | Fabricante: $fabricante"

                    # Guardar solo si es nuevo
                    if ! grep -q "$mac_trimmed" "$LOG_FILE"; then
                        echo "$timestamp,$mac_trimmed,$ssid,$fabricante" >> "$LOG_FILE"
                    fi
                fi
            done
        done
    fi

    sleep "$SLEEP_INTERVAL"
done
