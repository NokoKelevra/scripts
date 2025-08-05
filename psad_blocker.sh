#!/bin/bash

# Archivos y listas
TOP_ATTACKERS="/var/log/psad/top_attackers"
WHITELIST="/etc/psad/whitelist.txt"
BLACKLIST="/etc/psad/blacklist.txt"

# Crear archivos si no existen
touch "$WHITELIST" "$BLACKLIST"

# Función para bloquear una IP si no está en whitelist o ya bloqueada
block_ip() {
    local ip=$1

    # Revisar si está en la whitelist
    if grep -Fxq "$ip" "$WHITELIST"; then
        echo "[INFO] $ip está en la whitelist, se omite."
        return
    fi

    # Revisar si ya está en la blacklist
    if grep -Fxq "$ip" "$BLACKLIST"; then
        echo "[INFO] $ip ya está en la blacklist, se omite."
        return
    fi

    # Bloquear IP (usando iptables, puedes cambiar a ipset si prefieres)
    echo "[BLOQUEO] Bloqueando $ip..."
    iptables -A INPUT -s "$ip" -j DROP

    # Guardar en la blacklist
    echo "$ip" >> "$BLACKLIST"
}

echo "[*] Procesando IPs con DL >= 3 desde $TOP_ATTACKERS"

# Leer y procesar el archivo
grep -v '^#' "$TOP_ATTACKERS" | while read -r ip dl _; do
    if [ "$dl" -ge 3 ]; then
        block_ip "$ip"
    fi
done

echo "[✓] Proceso completado."
