#!/bin/bash

# ==============================
# Selección de archivo de log
# ==============================
if [ -n "$1" ]; then
    LOGFILE="$1"
else
    LOGFILE=$(ls -t "$HOME/logs_encendido"/encendido_*.log 2>/dev/null | head -n 1)
fi

if [ ! -f "$LOGFILE" ]; then
    echo "Archivo de log no encontrado: $LOGFILE"
    exit 1
fi

# ==============================
# Cálculo de tiempo encendido
# ==============================
start=$(head -n 1 "$LOGFILE")
end=$(tail -n 1 "$LOGFILE")

echo "Inicio: $start"
echo "Fin:    $end"

start_epoch=$(date -d "$start" +%s)
end_epoch=$(date -d "$end" +%s)

duration=$((end_epoch - start_epoch))

echo "Duración encendido: $((duration / 3600))h $(((duration % 3600) / 60))m $((duration % 60))s"

# ==============================
# Comprobación de voltaje
# ==============================
THROTTLED=$(vcgencmd get_throttled | cut -d= -f2)

echo "Estado voltaje:"

# Bit 0 → undervoltage ahora
if (( THROTTLED & 0x1 )); then
    echo "  ⚠️  Undervoltage ACTUAL"
else
    echo "  ✅ Voltaje correcto ahora"
fi

# Bit 16 → undervoltage ocurrió antes
if (( THROTTLED & 0x10000 )); then
    echo "  ⚠️  Hubo UNDERVOLTAGE durante el encendido"
else
    echo "  ✅ No se detectaron eventos de undervoltage"
fi
