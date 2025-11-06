#!/usr/bin/env python3
"""
emular_drone.py
Emula un dron (beacon frames) cambiando MAC y poniendo la interfaz en modo monitor.
Restaura MAC e interfaz al recibir Ctrl+C.

Uso:
  sudo ./emular_drone.py <iface> <bssid> <ssid> [interval_seconds]

Ejemplo:
  sudo ./emular_drone.py wlan0 60:60:1f:aa:bb:cc "DJI-LAB" 0.12
"""

import sys
import os
import subprocess
import signal
import time
from threading import Event, Thread

try:
    from scapy.all import RadioTap, Dot11, Dot11Beacon, Dot11Elt, sendp
except Exception as e:
    print("Error: Scapy no está disponible. Instálalo: sudo apt install python3-scapy  (o usa pip en un venv).")
    print("Excepción:", e)
    sys.exit(1)

STOP = Event()

def run_cmd(cmd, check=True, capture=False):
    if capture:
        return subprocess.check_output(cmd, shell=True, text=True).strip()
    else:
        return subprocess.check_call(cmd, shell=True) if check else subprocess.call(cmd, shell=True)

def get_original_mac(iface):
    path = f"/sys/class/net/{iface}/address"
    try:
        with open(path, "r") as f:
            return f.read().strip()
    except Exception:
        # fallback a ip link
        try:
            out = run_cmd(f"ip link show {iface}", check=True, capture=True)
            for part in out.split():
                if ":" in part and len(part) == 17 and part.count(":") == 5:
                    return part
        except Exception:
            return None
    return None

def set_interface_down(iface):
    run_cmd(f"ip link set {iface} down")

def set_interface_up(iface):
    run_cmd(f"ip link set {iface} up")

def set_iface_type(iface, itype):
    # itype: monitor or managed
    # Attempt using iw
    try:
        run_cmd(f"iw dev {iface} set type {itype}")
    except subprocess.CalledProcessError:
        # Some systems use airmon-ng to create monitor interfaces instead; we try a fallback (best-effort).
        print(f"[!] No se pudo cambiar tipo con 'iw' a '{itype}' en {iface}.")
        # nothing else to do automatically

def set_mac_address(iface, mac):
    # use ip link to set address (works when iface is down)
    run_cmd(f"ip link set dev {iface} address {mac}")

def restore_original_state(iface, original_mac):
    print("\n[*] Restaurando estado original...")
    try:
        set_interface_down(iface)
    except Exception:
        pass
    # intentar poner modo managed
    try:
        set_iface_type(iface, "managed")
    except Exception:
        pass
    # restaurar mac
    if original_mac:
        try:
            set_mac_address(iface, original_mac)
        except Exception as e:
            print("[!] No se pudo restaurar MAC original con ip link:", e)
    try:
        set_interface_up(iface)
    except Exception:
        pass
    print("[*] Restauración completada.")

def beacon_sender(iface, bssid, ssid, interval):
    # construir trama beacon
    dot11 = Dot11(type=0, subtype=8, addr1="ff:ff:ff:ff:ff:ff", addr2=bssid, addr3=bssid)
    beacon = Dot11Beacon(cap="ESS")
    essid = Dot11Elt(ID="SSID", info=ssid, len=len(ssid))
    frame = RadioTap()/dot11/beacon/essid
    print(f"[*] Empezando envío de beacons: SSID='{ssid}' BSSID={bssid} por {iface} (interval {interval}s). Ctrl+C para parar.")
    try:
        while not STOP.is_set():
            sendp(frame, iface=iface, verbose=False)
            # sendp has no precise sleep guarantee, use small sleep to control pace
            time.sleep(interval)
    except Exception as e:
        print("[!] Error en envío de beacons:", e)

def sigint_handler(sig, frame):
    STOP.set()

def main():
    if os.geteuid() != 0:
        print("Este script requiere permisos root. Ejecuta con sudo.")
        sys.exit(1)

    if len(sys.argv) < 4:
        print("Uso: sudo ./emular_drone.py <iface> <bssid> <ssid> [interval_seconds]")
        sys.exit(1)

    iface = sys.argv[1]
    bssid = sys.argv[2].lower()
    ssid = sys.argv[3]
    interval = float(sys.argv[4]) if len(sys.argv) > 4 else 0.1

    print("[*] Interfaz:", iface)
    # comprobar que la interfaz existe
    if not os.path.exists(f"/sys/class/net/{iface}"):
        print(f"Error: La interfaz {iface} no existe.")
        sys.exit(1)

    original_mac = get_original_mac(iface)
    print("[*] MAC original:", original_mac if original_mac else "(no disponible)")

    # preparar restauración en caso de Ctrl+C
    signal.signal(signal.SIGINT, sigint_handler)
    signal.signal(signal.SIGTERM, sigint_handler)

    try:
        # bajar interfaz
        print("[*] Bajando interfaz...")
        set_interface_down(iface)
        # cambiar mac
        print(f"[*] Cambiando MAC a {bssid} ...")
        try:
            set_mac_address(iface, bssid)
        except subprocess.CalledProcessError as e:
            print("[!] Falló cambiar MAC con ip link. Intentando macchanger...")
            try:
                run_cmd(f"macchanger -m {bssid} {iface}")
            except Exception as e2:
                print("[!] macchanger también falló:", e2)
                raise

        # poner interfaz en modo monitor
        print("[*] Poniendo interfaz en modo monitor...")
        try:
            set_iface_type(iface, "monitor")
        except Exception:
            pass
        # subir interfaz
        set_interface_up(iface)
        # confirmación (no obligatorio)
        try:
            cur_mac = get_original_mac(iface)
            print("[*] MAC actual en interfaz:", cur_mac)
        except Exception:
            pass

        # lanzar thread que envía beacons
        t = Thread(target=beacon_sender, args=(iface, bssid, ssid, interval))
        t.start()

        # esperar a que se pulse Ctrl+C
        while not STOP.is_set():
            time.sleep(0.2)

        # parada ordenada
        print("\n[*] Señal de parada recibida. Parando envío...")
        STOP.set()
        t.join(timeout=5)

    except Exception as e:
        print("[!] Excepción durante ejecución:", e)
    finally:
        # restaurar interfaz y mac
        restore_original_state(iface, original_mac)

if __name__ == "__main__":
    main()

