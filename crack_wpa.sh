#!/bin/bash

# Comprobaciones iniciales
if [ $# -ne 2 ]; then
  echo "Uso: $0 <archivo.22000> <diccionario.txt>"
  exit 1
fi

HASH_FILE="$1"
WORDLIST="$2"
OUT_DIR="$HOME/wpa_results"
OUT_RAW="$OUT_DIR/resultados_raw.txt"
OUT_CLEAN="$OUT_DIR/resultados_unicos.txt"
OUT_TOTAL="$OUT_DIR/resultados_totales.txt"

# Crear directorio de salida
mkdir -p "$OUT_DIR"

# Ejecutar hashcat (modo WPA-PBKDF2)
echo "[*] Ejecutando Hashcat..."
hashcat -m 22000 -a 0 "$HASH_FILE" "$WORDLIST" --force --quiet

# Mostrar resultados
echo "[*] Extrayendo contraseñas crackeadas..."
hashcat -m 22000 --show "$HASH_FILE" > "$OUT_RAW"

# Limpiar duplicados de las dos ultimas columnas
echo "[*] Procesando resultados (ESSID:contraseña)..."
awk -F ':' '{print $(NF-1) ":" $NF}' "$OUT_RAW" | sort -u > "$OUT_CLEAN"

# Notificación
echo "WPA Cracking completado" | notify
if [ -s "$OUT_CLEAN" ]; then
  # Añadir contenido y eliminar duplicados
  cat "$OUT_CLEAN" >> "$OUT_TOTAL"
  sort -u "$OUT_TOTAL" -o "$OUT_TOTAL"
  cat $OUT_CLEAN | notify
else
  echo "[!] No se encontró ninguna contraseña válida." | notify
fi
