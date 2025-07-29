#!/bin/bash

# Intervalo entre registros (en segundos)
INTERVALO=10

# Directorio donde se guardarán los registros
DIR_LOGS="$HOME/logs_encendido"
mkdir -p "$DIR_LOGS"

# Nombre del archivo con marca de tiempo
ARCHIVO_LOG="$DIR_LOGS/encendido_$(date '+%Y-%m-%d_%H-%M-%S').log"

# Mensaje inicial
echo "Iniciando registro de encendido en: $ARCHIVO_LOG"
echo "Presiona Ctrl+C para detener."

# Bucle que guarda la hora actual cada X segundos
while true; do
    echo "$(date '+%Y-%m-%d %H:%M:%S')" >> "$ARCHIVO_LOG"
    sleep "$INTERVALO"
done
