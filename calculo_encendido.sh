#!/bin/bash

# Si se pasa un argumento, úsalo como archivo de log
if [ -n "$1" ]; then
    LOGFILE="$1"
else
    # Si no, usar el más reciente en ~/logs_encendido/
    LOGFILE=$(ls -t "$HOME/logs_encendido"/encendido_*.log 2>/dev/null | head -n 1)
fi

# Verificar existencia
if [ ! -f "$LOGFILE" ]; then
    echo "Archivo de log no encontrado: $LOGFILE"
    exit 1
fi

start=$(head -n 1 "$LOGFILE")
end=$(tail -n 1 "$LOGFILE")

echo "Inicio: $start"
echo "Fin:    $end"

start_epoch=$(date -d "$start" +%s)
end_epoch=$(date -d "$end" +%s)

duration=$((end_epoch - start_epoch))

echo "Duración encendido: $((duration / 3600))h $(((duration % 3600) / 60))m $((duration % 60))s"