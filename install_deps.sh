#!/bin/bash

#Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}--- Iniciando instalación de dependencias ---${NC}"

# Verificar si es usuario root
if [ "$EUID" -ne 0 ]; then 
  echo -e "${RED}Por favor, ejecuta este script como root o usando sudo.${NC}"
  exit 1
fi
if command -v apt-get &> /dev/null; then
    echo "Detectado sistema basado en Debian/Ubuntu (apt)..."
    apt-get update -y && apt-get install -y curl jq whois
elif command -v dnf &> /dev/null; then
    echo "Detectado sistema basado en Fedora/RHEL (dnf)..."
    dnf install -y curl jq whois
elif command -v pacman &> /dev/null; then
    echo "Detectado sistema basado en Arch Linux (pacman)..."
    pacman -Sy --noconfirm curl jq whois
else
    echo -e "${RED}No se pudo identificar el gestor de paquetes. Instala curl, jq y whois manualmente.${NC}"
    exit 1
fi

echo -e "\n${GREEN}Verificando herramientas:${NC}"
for tool in curl jq whois; do
    if command -v $tool &> /dev/null; then
        echo -e "  [OK] $tool"
    else
        echo -e "  [ERROR] No se pudo instalar $tool"
    fi
done

echo -e "\n${GREEN}Instalando en comandos locales......${NC}"
cp ipChecker.sh /usr/local/bin/ipChecker
chmod +x /usr/local/bin/ipChecker

# Dar permisos de ejecución al script principal
if [ -f "ipChecker.sh" ]; then
    chmod +x ipChecker.sh
    echo -e "\n${GREEN}Permisos aplicados a ipChecker.sh${NC}"
    chmod +x /usr/local/bin/ipChecker
    echo -e "\n${GREEN}Permisos aplicados a /usr/local/bin/ipChecker${NC}"
fi
echo -e "\n${GREEN}¡Listo! Ya puedes usar el script.${NC}"
