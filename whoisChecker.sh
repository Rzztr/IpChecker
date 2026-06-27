#!/bin/bash

# Función para mostrar el uso correcto del script
mostrar_ayuda() {
    echo "Uso: $0 -wH <archivo_de_ips.txt>"
    echo "Ejemplo: $0 -wH lista_ips.txt"
    exit 1
}

# Validar que se pasen exactamente dos argumentos
if [ "$#" -ne 2 ]; then
    mostrar_ayuda
fi

# Validar que el primer argumento sea estrictamente -wH
if [ "$1" != "-wH" ]; then
    echo "Error: Argumento no válido '$1'"
    mostrar_ayuda
fi

# Asignar el archivo de entrada a una variable
ARCHIVO_IPS="$2"

# Verificar si el archivo de IPs existe
if [ ! -f "$ARCHIVO_IPS" ]; then
    echo "Error: El archivo '$ARCHIVO_IPS' no existe."
    exit 1
fi

# Definir el archivo de salida
ARCHIVO_SALIDA="resultado_whois_$(date +%Y%m%d_%H%M%S).txt"

echo "=== Iniciando auditoría de WHOIS ==="
echo "Procesando IPs desde: $ARCHIVO_IPS"
echo "Resultados se guardarán en: $ARCHIVO_SALIDA"
echo "------------------------------------------------"

# Asegurar que el archivo de salida esté limpio/creado
> "$ARCHIVO_SALIDA"

# Contador para visualización en terminal
contador=0

# Leer el archivo línea por línea
while IFS= read -r ip || [ -n "$ip" ]; do
    # Limpiar espacios en blanco o saltos de línea extraños (\r de Windows)
    ip=$(echo "$ip" | tr -d '\r' | xargs)

    # Ignorar líneas vacías o comentarios
    if [ -z "$ip" ] || [[ "$ip" == \#* ]]; then
        continue
    fi

    ((contador++))
    echo "[$contador] Consultando WHOIS para: $ip..."

    # Escribir encabezado de la IP en el archivo de salida
    echo "==================================================" >> "$ARCHIVO_SALIDA"
    echo " IP: $ip" >> "$ARCHIVO_SALIDA"
    echo " Fecha de consulta: $(date '+%Y-%m-%d %H:%M:%S')" >> "$ARCHIVO_SALIDA"
    echo "==================================================" >> "$ARCHIVO_SALIDA"

    # Ejecutar el comando whois y redirigir la salida al archivo
    # Se añade un timeout de 10 segundos por si un servidor no responde
    if command -v whois &> /dev/null; then
        whois "$ip" >> "$ARCHIVO_SALIDA" 2>&1
    else
        echo "Error: El comando 'whois' no está instalado en este sistema Debian." | tee -a "$ARCHIVO_SALIDA"
        echo "Instálalo ejecutando: sudo apt install whois"
        exit 1
    fi

    # Añadir saltos de línea para separar los bloques de IPs
    echo -e "\n\n" >> "$ARCHIVO_SALIDA"

done < "$ARCHIVO_IPS"

echo "------------------------------------------------"
echo "¡Proceso terminado con éxito!"
echo "Total de IPs procesadas: $contador"
echo "Resultados almacenados en: ./$ARCHIVO_SALIDA"
