# LEE BIEN ESTE README

## IP Checker

Este proyecto es una herramienta desarrollada en Bash (`ipChecker.sh`) que permite analizar direcciones IP para obtener información sobre su reputación y detalles de red. Utiliza la API de AbuseIPDB para consultar el nivel de riesgo de una IP, así como `whois` y `ping` para obtener datos adicionales sobre la organización, el país y la disponibilidad del host.

### Requisitos Previos

Para que el script funcione correctamente, asegúrate de tener instaladas las siguientes dependencias en tu sistema:
- `ping` (generalmente incluido por defecto en sistemas basados en Unix)
- `curl` (para realizar peticiones a la API)
- `jq` (para parsear la respuesta JSON de la API)
- `whois` (para obtener datos del registro de la IP)

Puedes instalar estas dependencias (en sistemas basados en Debian/Ubuntu) usando:
```bash
sudo apt update
sudo apt install curl jq whois
```
*(Nota: El repositorio incluye un archivo `install_deps.sh` que podría facilitar este proceso).*

### Uso

El script `ipChecker.sh` se puede ejecutar desde la terminal y soporta dos modos principales de operación:

1. **Analizar una IP individual:**
   Utiliza la opción `-g` o `--generar` seguida de la IP que deseas consultar.
   ```bash
   ./ipChecker.sh -g 8.8.8.8
   ```
   Esto realizará un ping al host, consultará su puntuación de abuso (AbuseIPDB), y mostrará la información de WHOIS.

2. **Analizar una lista de IPs desde un archivo:**
   Utiliza la opción `-i` o `--lista` seguida de la ruta a un archivo de texto (por ejemplo, `lista_ips.txt`) que contenga las direcciones IP a analizar (una por línea).
   ```bash
   ./ipChecker.sh -i lista_ips.txt
   ```
   Esto imprimirá una tabla con las IPs, su nivel de riesgo (Score), país y la organización a la que pertenecen.

3. **Ayuda:**
   Para ver el menú de opciones, simplemente ejecuta el script sin argumentos o con la opción `-h` o `--help`.
   ```bash
   ./ipChecker.sh -h
   ```

### Notas Importantes
- **API Key de AbuseIPDB:** El script viene con una clave de API configurada, pero si alcanzas el límite de consultas diarias, deberás registrarte en [AbuseIPDB](https://www.abuseipdb.com/) y reemplazar la variable `API_KEY` dentro del script `ipChecker.sh` por tu propia clave.
- Otorga permisos de ejecución al script antes de intentar correrlo:
  ```bash
  chmod +x ipChecker.sh
  ```
