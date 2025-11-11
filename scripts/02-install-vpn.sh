#!/usr/bin/env bash
set -euo pipefail

# 04-install-pivpn.sh
# Instala PiVPN y configura el reenvío de IP

echo "═══════════════════════════════════════════════════════════"
echo "  Instalación de PiVPN"
echo "═══════════════════════════════════════════════════════════"
echo

# Función para detectar si necesita sudo
USE_SUDO=false
if [ "$EUID" -ne 0 ]; then
  if sudo -n true 2>/dev/null; then
    USE_SUDO=true
    echo "⚠ Se usará 'sudo' para comandos privilegiados."
  else
    echo "✗ Error: Se requieren permisos de superusuario."
    exit 1
  fi
fi

run_sudo() {
  if [ "$USE_SUDO" = true ]; then
    sudo "$@"
  else
    "$@"
  fi
}

# Verificar si PiVPN ya está instalado
if command -v pivpn >/dev/null 2>&1; then
  echo "⚠ PiVPN parece estar ya instalado."
  
  read -p "¿Deseas continuar con la instalación? (s/n): " response < /dev/tty
  if [[ ! "$response" =~ ^[Ss]$ ]]; then
    echo "Cancelando instalación de PiVPN."
    exit 0
  fi
fi

# Ejecutar instalador de PiVPN
echo
echo "Descargando e iniciando instalador de PiVPN..."
echo "NOTA: El instalador será interactivo, sigue las instrucciones en pantalla."
echo
curl -L https://install.pivpn.io | bash

# Verificar si la instalación fue exitosa
if ! command -v pivpn >/dev/null 2>&1; then
  echo
  echo "✗ Error: La instalación de PiVPN no se completó correctamente."
  exit 1
fi

echo
echo "✓ PiVPN instalado correctamente."

# Configurar IP forwarding en /etc/sysctl.conf
echo
echo "Configurando reenvío de IP (ip_forward)..."

SYSCTL_FILE="/etc/sysctl.conf"
IP_FORWARD_LINE="net.ipv4.ip_forward=1"

# Verificar si ya está configurado
if run_sudo grep -q "^net.ipv4.ip_forward=1" "$SYSCTL_FILE" 2>/dev/null; then
  echo "✓ IP forwarding ya está habilitado en ${SYSCTL_FILE}"
else
  # Descomentar si existe comentado o añadir al final
  if run_sudo grep -q "^#net.ipv4.ip_forward=1" "$SYSCTL_FILE" 2>/dev/null; then
    echo "Descomentando línea existente..."
    run_sudo sed -i 's/^#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' "$SYSCTL_FILE"
  else
    echo "Añadiendo configuración al final del archivo..."
    echo "$IP_FORWARD_LINE" | run_sudo tee -a "$SYSCTL_FILE" > /dev/null
  fi
  
  echo "✓ IP forwarding configurado en ${SYSCTL_FILE}"
fi

# Aplicar cambios inmediatamente
echo
echo "Aplicando cambios de sysctl..."
run_sudo sysctl -p

# Verificar que el cambio está activo
IP_FORWARD_STATUS=$(cat /proc/sys/net/ipv4/ip_forward)
if [ "$IP_FORWARD_STATUS" = "1" ]; then
  echo "✓ IP forwarding está activo."
else
  echo "⚠ Advertencia: IP forwarding no está activo. Puede requerir reinicio."
fi

# Información final
echo
echo "═══════════════════════════════════════════════════════════"
echo "  ✓ Instalación completada"
echo "═══════════════════════════════════════════════════════════"
echo
echo "PiVPN instalado y configurado correctamente."
echo "IP forwarding habilitado: net.ipv4.ip_forward=1"
echo
echo "Para gestionar PiVPN, usa el comando: pivpn"
echo
echo "═══════════════════════════════════════════════════════════"

exit 0