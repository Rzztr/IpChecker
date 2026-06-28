#!/bin/bash

# --- Colores ---
G='\033[0;32m' # Verde
R='\033[0;31m' # Rojo
Y='\033[1;33m' # Amarillo
B='\033[0;34m' # Azul
CY='\033[0;36m' # Cian
NC='\033[0m'    # Sin color


ENV_PATH=""
if [ -f "./.env" ]; then
    ENV_PATH="./.env"
elif [ -f "$HOME/.env" ]; then
    ENV_PATH="$HOME/.env"
fi

if [ -n "$ENV_PATH" ]; then
    while read -r linea || [ -n "$linea" ]; do
        # Ignorar comentarios y líneas vacías
        [[ "$linea" =~ ^# ]] || [[ -z "$linea" ]] && continue
        export "$linea"
    done < "$ENV_PATH"
fi

API_KEY="${ABUSEIPDB_API_KEY:-$API_KEY}"

show_banner() {
    echo -e "${Y}"
    echo "  ██╗      ██████╗ ███████╗    ██╗   ██╗ █████╗  ██████╗ ██╗   ██╗███████╗██████╗  ██████╗ ███████╗"
    echo "  ██║     ██╔═══██╗██╔════╝    ██║   ██║██╔══██╗██╔═══██╗██║   ██║██╔════╝██╔══██╗██╔═══██╗██╔════╝"
    echo "  ██║     ██║   ██║███████╗    ██║   ██║███████║██║   ██║██║   ██║█████╗  ██████╔╝██║   ██║███████╗"
    echo "  ██║     ██║   ██║╚════██║    ╚██╗ ██╔╝██╔══██║██║▄▄ ██║██║   ██║██╔══╝  ██╔══██╗██║   ██║╚════██║"
    echo "  ███████╗╚██████╔╝███████║     ╚████╔╝ ██║  ██║╚██████╔╝╚██████╔╝███████╗██║  ██║╚██████╔╝███████║"
    echo "  ╚══════╝ ╚═════╝ ╚══════╝      ╚═══╝  ╚═╝  ╚═╝ ╚══▀▀═╝  ╚═════╝ ╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝"
    echo -e "                                      IP CHECKER v3.0${NC}"
}
exchange(){
    sleep 0.5
    echo -e "\n${CY}0================================================================================================0${NC}\n"
}

ping_host(){
    local target=$1
    echo -e "${B}[*] Revisando si $target está activo...${NC}"
    if ping -c 1 -W 2 "$target" > /dev/null 2>&1; then
        echo -e "${G}[+] Host activo${NC}"
    else
        echo -e "${R}[-] Host inactivo o bloquea ICMP${NC}"
    fi
}

procesar_fuente() {
    local entrada="$*"
    if [[ -f "$entrada" && ("$entrada" == *.txt || "$entrada" == *.log) ]]; then
        cat "$entrada" | tr -d '\r'
    else
        echo "$entrada" | tr ' ' '\n' | sed -e '$a\'
    fi
}

abuseIp_Script(){
    local FUENTE="$1"
    local GUARDAR_ARCHIVO="$2"
    local SALIDA_TXT="reputacion_ips_$(date +%Y%m%d_%H%M%S).txt"

    if [ "$GUARDAR_ARCHIVO" = true ]; then
        echo -e "${Y}[*] Guardando reporte de reputación en: ./$SALIDA_TXT${NC}"
        exec 3>&1 >>"$SALIDA_TXT"
    fi

    echo -e "${Y}INICIANDO ANÁLISIS DE REPUTACIÓN...${NC}"
    printf "${B}%-18s | %-7s | %-6s | %-30s${NC}\n" "IP" "SCORE" "PAÍS" "ORGANIZACIÓN"
    echo "--------------------------------------------------------------------------------------------------"

    # Se evita el uso de tuberías directas para prevenir aislamiento de subshell
    while read -r linea || [ -n "$linea" ]; do
        ip=$(echo "$linea" | tr -d '[] -' | xargs)
        
        if [[ -z "$ip" || "$ip" == \#* || ! "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            continue
        fi
            
        if [ -n "$API_KEY" ]; then
            RESPONSE=$(curl -s -G https://api.abuseipdb.com/api/v2/check \
              --data-urlencode "ipAddress=$ip" \
              -d maxAgeInDays=90 \
              -H "Key: $API_KEY" \
              -H "Accept: application/json")
            
            SCORE=$(echo "$RESPONSE" | jq -r '.data.abuseConfidenceScore' 2>/dev/null)
            [[ "$SCORE" == "null" || -z "$SCORE" ]] && SCORE="0"
            
            if [ "$GUARDAR_ARCHIVO" = true ]; then
                S_COL="" NC_L=""
            else
                if [ "$SCORE" -gt 50 ]; then S_COL=$R; elif [ "$SCORE" -gt 10 ]; then S_COL=$Y; else S_COL=$G; fi
                NC_L=$NC
            fi
        else
            # Si no hay API KEY cargada del archivo .env
            SCORE="?"
            S_COL=$Y NC_L=$NC
        fi

        WHOIS_RAW=$(whois "$ip" 2>/dev/null)
        COUNTRY=$(echo "$WHOIS_RAW" | grep -Ei "^country:" | head -n 1 | cut -d: -f2 | xargs | tr '[:lower:]' '[:upper:]' | cut -c1-2)
        [ -z "$COUNTRY" ] && COUNTRY="??"
        
        ORG=$(echo "$WHOIS_RAW" | grep -Ei "orgname|descr|organization" | head -n 1 | cut -d: -f2 | xargs | cut -c1-30)
        [ -z "$ORG" ] && ORG="Desconocido"
        
        printf "%-18s | %b%-3s%%%b   | %-6s | %-30s\n" "$ip" "$S_COL" "$SCORE" "$NC_L" "$COUNTRY" "$ORG"
    done < <(procesar_fuente "$FUENTE")

    if [ "$GUARDAR_ARCHIVO" = true ]; then
        exec 1>&3 3>&-
        echo -e "${G}[+] ¡Reporte guardado con éxito!${NC}"
    fi
}

is_tor(){
    local ip_suspicius="$1"
    if [ -z "$ip_suspicius" ]; then
        echo -e "${R}Error: No se proporcionó una IP para verificar.${NC}"
        return 1
    fi

    if curl -s "https://check.torproject.org/cgi-bin/TorBulkExitList.py?ip=8.8.8.8" | grep -q "^${ip_suspicius}$"; then
        echo -e "${R}[!] La IP $ip_suspicius es un nodo de salida de Tor.${NC}"
    else
        echo -e "${G}[+] La IP $ip_suspicius no es un nodo de salida de Tor.${NC}"
    fi
}

check_tor(){
    local ip="$1"
    if [ -z "$ip" ]; then
        echo -e "${R}Error: No se proporcionó una IP para verificar.${NC}"
        return 1
    fi  

    echo -e "IP's tor que alcanzan al host: $ip"
    curl -sL "https://check.torproject.org/cgi-bin/TorBulkExitList.py?ip=$ip"
}

whois_data(){
    echo -e "${Y}--- DATOS WHOIS RESUMIDOS ---${NC}"
    whois "$1" | grep -E "NetRange|NetName|Organization|RegDate|City|Address" | sed 's/^/  /'
}

auditoria_whois_completa(){
    local ENTRADA="$1"
    local GUARDAR_ARCHIVO="$2"
    
    if ! command -v whois &> /dev/null; then
        echo -e "${R}Error: El comando 'whois' no está instalado.${NC}"
        exit 1
    fi

    local ARCHIVO_SALIDA="resultado_whois_$(date +%Y%m%d_%H%M%S).txt"

    echo -e "${Y}=== Iniciando auditoría completa de WHOIS ===${NC}"
    if [ "$GUARDAR_ARCHIVO" = true ]; then
        echo "Resultados se guardarán en: ./$ARCHIVO_SALIDA"
        > "$ARCHIVO_SALIDA"
    else
        echo "Mostrando resultados en pantalla..."
    fi
    echo "------------------------------------------------"

    local contador=0

    # Redirección de proceso avanzada para asegurar que $contador incremente globalmente
    while read -r linea || [ -n "$linea" ]; do
        ip=$(echo "$linea" | tr -d '[] -' | xargs)

        if [[ -z "$ip" || "$ip" == \#* || ! "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            continue
        fi

        ((contador++))
        
        if [ "$GUARDAR_ARCHIVO" = true ]; then
            echo "[$contador] Consultando WHOIS completo para: $ip..."
            {
                echo "=================================================="
                echo " IP: $ip"
                echo " Fecha de consulta: $(date '+%Y-%m-%d %H:%M:%S')"
                echo "=================================================="
                whois "$ip"
                echo -e "\n\n"
            } >> "$ARCHIVO_SALIDA" 2>&1
        else
            echo -e "${B}[$contador] WHOIS completo para: $ip${NC}"
            echo "=================================================="
            whois "$ip" 2>/dev/null
            echo "=================================================="
            echo -e "\n"
        fi
    done < <(procesar_fuente "$ENTRADA")

    echo "------------------------------------------------"
    echo -e "${G}¡Proceso terminado con éxito!${NC}"
    echo "Total de IPs procesadas: $contador"
}

# ==========================================
# 🕹️ CONTROLADORES DE ENTRADA (CASE)
# ==========================================

OPCION="$1"
shift

if [ -z "$OPCION" ]; then
    OPCION="-h"
fi

# Ejecuta show_banner únicamente si la función está declarada en otra parte del entorno
if declare -f show_banner > /dev/null; then
    show_banner
fi

# Detectar bandera -o al final de los argumentos para guardar en archivo
GUARDAR=false
ARGUMENTOS="$*"
if [[ "$ARGUMENTOS" =~ \ -o$ ]]; then
    GUARDAR=true
    ARGUMENTOS="${ARGUMENTOS% -o}"
fi

case "$OPCION" in 
    -g|--generar)
        if [ -z "$ARGUMENTOS" ]; then echo -e "${R}Error: Debes proporcionar una IP individual${NC}"; exit 1; fi
        exchange
        ping_host "$ARGUMENTOS"
        abuseIp_Script "$ARGUMENTOS" false
        exchange
        whois_data "$ARGUMENTOS"
        exchange
    ;;
    -i|--lista)
        if [ -z "$ARGUMENTOS" ]; then echo -e "${R}Error: Debes proporcionar IPs o un archivo${NC}"; exit 1; fi
        exchange
        abuseIp_Script "$ARGUMENTOS" "$GUARDAR"
        exchange
    ;;
    -w|--whois)
        if [ -z "$ARGUMENTOS" ]; then echo -e "${R}Error: Debes proporcionar IPs o un archivo${NC}"; exit 1; fi
        exchange
        auditoria_whois_completa "$ARGUMENTOS" "$GUARDAR"
        exchange
    ;;
    -isTor|--tor)
        if [ -z "$ARGUMENTOS" ]; then echo -e "${R}Error: Debes proporcionar una IP para verificar${NC}"; exit 1; fi
        exchange
        is_tor "$ARGUMENTOS"
        exchange
    ;;
    -cT | --checkTor)
        if [ -z "$ARGUMENTOS" ]; then echo -e "${R}Error: Debes proporcionar una IP para verificar${NC}"; exit 1; fi
        exchange
        check_tor "$ARGUMENTOS"
        exchange
    ;;  
    -h|--help|*)
        echo -e "${Y}Modo de uso:${NC} $0 [opción] [IPs / archivo] [-o]"
        echo -e "\nOpciones disponibles:"
        echo -e "  ${G}-g, --generar${NC}  [IP]            Analiza una sola IP (Ping + Reputación + Resumen WHOIS)"
        echo -e "  ${G}-i, --lista${NC}    [IPs/Archivo]   Ver reputación en consola. Agrega ${Y}-o${NC} al final para TXT"
        echo -e "  ${G}-w, --whois${NC}    [IPs/Archivo]   Ver WHOIS completo en consola. Agrega ${Y}-o${NC} al final para TXT"
        echo -e "  ${G}-isTor, --tor${NC}  [IP]            Verifica si la IP es un nodo de salida de Tor"
        echo -e "  ${G}-cT, --checkTor${NC} [IP]            Lista de IPs de salida de Tor que alcanzan a la IP dada"
        echo -e "  ${G}-h, --help${NC}                    Muestra este menú"
        echo -e "\nEjemplos prácticos:"
        echo -e "  $0 -g 8.8.8.8"
        echo -e "  $0 -i 8.8.8.8 1.1.1.1 1.0.0.1"
        echo -e "  $0 -i lista_ips.txt -o"
        echo -e "  $0 -w 8.8.8.8 34.19.116.53 -o"
        exchange
    ;;
esac