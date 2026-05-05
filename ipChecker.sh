#!/bin/bash

# --- Colores ---
G='\033[0;32m' # Verde
R='\033[0;31m' # Rojo
Y='\033[1;33m' # Amarillo
B='\033[0;34m' # Azul
CY='\033[0;36m' # Cian
NC='\033[0m'    # Sin color

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

abuseIp_Script(){
    local FUENTE=$1
    API_KEY="7e2dea7a48e4bccbaf8205556fba585cfc16f53a0b487646f4f0e46691026db673c302363d0f0001"

    echo -e "${Y}INICIANDO ANÁLISIS DE REPUTACIÓN...${NC}"
    printf "${B}%-18s | %-7s | %-6s | %-30s${NC}\n" "IP" "SCORE" "PAÍS" "ORGANIZACIÓN"
    echo "--------------------------------------------------------------------------------------------------"

    if [ -f "$FUENTE" ]; then
        ENTRADA=$(cat "$FUENTE")
    else
        ENTRADA=$FUENTE
    fi

    echo "$ENTRADA" | while read -r linea || [ -n "$linea" ]; do
        ip=$(echo "$linea" | tr -d '[] -' | xargs)
        
        if [[ ! "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            continue
        fi

        if [[ "$API_KEY" != "TU_API_KEY_AQUI" && -n "$API_KEY" ]]; then
            RESPONSE=$(curl -s -G https://api.abuseipdb.com/api/v2/check \
              --data-urlencode "ipAddress=$ip" \
              -d maxAgeInDays=90 \
              -H "Key: $API_KEY" \
              -H "Accept: application/json")
            
            SCORE=$(echo "$RESPONSE" | jq -r '.data.abuseConfidenceScore' 2>/dev/null)
            [[ "$SCORE" == "null" || -z "$SCORE" ]] && SCORE="0"
            
            if [ "$SCORE" -gt 50 ]; then S_COL=$R; elif [ "$SCORE" -gt 10 ]; then S_COL=$Y; else S_COL=$G; fi
        else
            SCORE="0"
            S_COL=$NC
        fi

        WHOIS_RAW=$(whois "$ip" 2>/dev/null)
        COUNTRY=$(echo "$WHOIS_RAW" | grep -Ei "^country:" | head -n 1 | cut -d: -f2 | xargs | tr '[:lower:]' '[:upper:]' | cut -c1-2)
        [ -z "$COUNTRY" ] && COUNTRY="??"
        
        ORG=$(echo "$WHOIS_RAW" | grep -Ei "orgname|descr|organization" | head -n 1 | cut -d: -f2 | xargs | cut -c1-30)
        [ -z "$ORG" ] && ORG="Desconocido"
        
        printf "%-18s | %b%-3s%%%b   | %-6s | %-30s\n" "$ip" "$S_COL" "$SCORE" "$NC" "$COUNTRY" "$ORG"
    done
}

whois_data(){
    echo -e "${Y}--- DATOS WHOIS COMPLETOS ---${NC}"
    whois "$1" | grep -E "NetRange|NetName|Organization|RegDate|City|Address" | sed 's/^/  /'
}

if [ -z "$1" ]; then
    set -- "-h"
fi

clear
show_banner

case "$1" in 
    -g|--generar)
        if [ -z "$2" ]; then echo -e "${R}Error: Debes proporcionar una IP${NC}"; exit 1; fi
        exchange
        ping_host "$2"
        abuseIp_Script "$2"
        exchange
        whois_data "$2"
        exchange
    ;;
    -i|--lista)
        if [ -z "$2" ]; then 
            echo -e "${R}Error: Debes proporcionar la ruta de un archivo (ej: ./mis_ips.txt)${NC}"
            exit 1
        fi
        if [ ! -f "$2" ]; then 
            echo -e "${R}Error: El archivo '$2' no existe.${NC}"
            exit 1
        fi
        exchange
        abuseIp_Script "$2"
        exchange
    ;;
    -h|--help|*)
        echo -e "${Y}Modo de uso:${NC} $0 [opciones] [argumento]"
        echo -e "\nOpciones:"
        echo -e "  ${G}-g, --generar [IP]${NC}       Analiza una IP individual"
        echo -e "  ${G}-i, --lista [ARCHIVO]${NC}    Analiza IPs desde un archivo de texto"
        echo -e "  ${G}-h, --help${NC}               Muestra este menú"
        exchange
    ;;
esac