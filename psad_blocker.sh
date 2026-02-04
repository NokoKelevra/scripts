#!/bin/bash
set -euo pipefail

# Entorno mínimo para cron
PATH=/usr/sbin:/usr/bin:/sbin:/bin

# Logging
LOGFILE="/var/log/psad_blocker.log"
exec >> "$LOGFILE" 2>&1

echo "=============================="
echo "[INFO] Ejecución: $(date)"

# Archivos y listas
TOP_ATTACKERS="/var/log/psad/top_attackers"
WHITELIST="/etc/psad/whitelist.txt"
BLACKLIST="/etc/psad/blacklist.txt"

# Comprobaciones básicas
[[ -r "$TOP_ATTACKERS" ]] || { echo "[ERROR] No se puede leer $TOP_ATTACKERS"; exit 1; }

# Crear archivos si no existen
touch "$WHITELIST" "$BLACKLIST"
chmod 644 "$WHITELIST" "$BLACKLIST"

# Función para bloquear una IP
block_ip() {
    local ip="$1"

    # Validación básica de IP (evita basura)
    [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || {
        echo "[WARN] IP inválida: $ip"
        return
    }

    if grep -Fxq "$ip" "$WHITELIST"; then
        echo "[INFO] $ip en whitelist, se omite."
        return
    fi

    if grep -Fxq "$ip" "$BLACKLIST"; then
        echo "[INFO] $ip ya en blacklist, se omite."
        return
    fi

    # Evitar reglas duplicadas en iptables
    if /sbin/iptables -C INPUT -s "$ip" -j DROP 2>/dev/null; then
        echo "[INFO] Regla iptables ya existe para $ip"
    else
        echo "[BLOQUEO] Bloqueando $ip"
        /sbin/iptables -A INPUT -s "$ip" -j DROP
    fi

    echo "$ip" >> "$BLACKLIST"
}

echo "[INFO] Procesando IPs con DL >= 3"

# Procesar el archivo sin subshell
while read -r ip dl _; do
    [[ -z "$ip" || "$ip" =~ ^# ]] && continue
    if [[ "$dl" =~ ^[0-9]+$ && "$dl" -ge 3 ]]; then
        block_ip "$ip"
    fi
done < <(grep -v '^#' "$TOP_ATTACKERS")

echo "[OK] Proceso completado"
