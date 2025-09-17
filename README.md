# Script varios en BASH

_Diferentes Scripts en Bash desarrollados para aprender sobre automatización el Linux_

## Monitor (monitor.sh)
_Ejecución de diferentes instrucciones para comprobar el estado del dispositivo._

Herramientas necesarias:

* [echo]- El comando para la impresión de un texto en pantalla
* [mpstat]- Herramienta utilizada en sistemas Linux para mostrar estadísticas de actividad de los procesadores (CPU)
* [awk]- Herramienta para procesar y analizar archivos de texto
* [free]- Herramienta para mostrar estadísticas sobre el uso de la memoria del sistema
* [df]- Herramienta que muestra el uso del disco duro y otras informaciones como punto de montaje y sistema de ficheros
* [ifstat]- Herramienta utilizada para monitorizar en tiempo real el tráfico de red
* [ps]- Herramienta que permite visualizar información detallada acerca de los procesos que se están ejecutando en un sistema
* [head]- Herramienta utilizada para mostrar las primeras líneas de un archivo de texto
* [journalctl]- Herramienta utilizada para consultar y gestionar los registros del sistema
  
```
./monitor.sh
```
## Scope Process (scope_process.sh)
_Este script se ha desarrollado para extraer y separar los dominios, subdominios y wildcards de un archivo CSV de Scope de un programa de HackerOne. Obtendremos como resultado tres archivos que contendràn la información de wildcards, los dominios totales y los dominios sin repetición en el caso que pudieran existir._

```
./scope_process.sh <archivo_csv> <carpeta_destino>
```
## Log Encendido (log_encendido.sh)
_Crea un archivo y guarda en él un registro de tiempo cada intervalo de segundos que hemos definido, por defecto 10 segundos._

```
./log_encendido.sh
```
## Calculo encendido (calculo_encendido.sh)
_Calcula cuanto tiempo ha estado encendido un dispositivo. Se puede pasar un archivo por argumento para calcular el encendido en un momento concreto o, si se ejecuta sin argumento, calcula el último archivo de encendido. Este script va vinculado a los archivos generados por el script log_encendido._

```
./calculo_encendido.sh <archivo_log>
```
## Escaneo PMKID (escaneo_PMKID_ciclos.sh)

## Crack WPA/PMKID (crack_wpa.sh)

## PSAD Blocker (psad_blocker.sh)
