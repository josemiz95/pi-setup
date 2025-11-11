#!/usr/bin/env bash
set -euo pipefail

# install-wireguard-ui.sh
# Instala WireGuard-UI en Docker con configuración completa

CONTAINER_NAME="wireguard-ui"
IMAGE_NAME="ngoduykhanh/wireguard-ui:latest"
WIREGUARD_DIR="/opt/wireguard-ui"
WIREGUARD_CONF_DIR="/etc/wireguard"
DEFAULT_USERNAME="admin"
DEFAULT_PASSWORD="admin123"
WEB_PORT="5000"

echo "═══════════════════════════════════════════════════════════"
echo "  Instalación de WireGuard-UI en Docker"
echo "═══════════════════════════════════════════════════════════"
echo

# Función para detectar si necesita sudo
USE_SUDO_DOCKER=false
if ! docker info >/dev/null 2>&1; then
  if sudo docker info >/dev/null 2>&1; then
    USE_SUDO_DOCKER=true
    echo "⚠ Se usará 'sudo' para comandos de Docker."
  else
    echo "✗ Error: No se puede conectar con Docker."
    exit 1
  fi
fi

run_docker() {
  if [ "$USE_SUDO_DOCKER" = true ]; then
    sudo docker "$@"
  else
    docker "$@"
  fi
}

# Verificar si WireGuard-UI ya está instalado
if run_docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  echo "⚠ El contenedor '${CONTAINER_NAME}' ya existe."
  
  read -p "¿Deseas eliminarlo y reinstalar? (s/n): " response < /dev/tty
  if [[ ! "$response" =~ ^[Ss]$ ]]; then
    echo "Cancelando instalación de WireGuard-UI."
    exit 0
  fi
  
  echo "Eliminando contenedor existente..."
  run_docker stop "$CONTAINER_NAME" 2>/dev/null || true
  run_docker rm "$CONTAINER_NAME" 2>/dev/null || true
fi

# Obtener IP pública
echo "Detectando IP pública..."
PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null || echo "")

if [ -z "$PUBLIC_IP" ]; then
  echo "⚠ No se pudo detectar la IP pública automáticamente."
  read -p "Introduce tu IP pública o dominio: " PUBLIC_IP < /dev/tty
else
  echo "✓ IP pública detectada: ${PUBLIC_IP}"
  read -p "¿Es correcta? (s/n - si 'n' introduce la correcta): " confirm < /dev/tty
  if [[ ! "$confirm" =~ ^[Ss]$ ]]; then
    read -p "Introduce tu IP pública o dominio: " PUBLIC_IP < /dev/tty
  fi
fi

# Pedir credenciales al usuario
echo
echo "Configuración de acceso a la UI:"
read -p "Usuario (Enter para '${DEFAULT_USERNAME}'): " WGUI_USERNAME < /dev/tty
read -p "Contraseña (Enter para '${DEFAULT_PASSWORD}'): " WGUI_PASSWORD < /dev/tty

# Si no se introducen, usar los por defecto
if [ -z "$WGUI_USERNAME" ]; then
  WGUI_USERNAME="$DEFAULT_USERNAME"
  echo "Usando usuario por defecto: ${DEFAULT_USERNAME}"
fi

if [ -z "$WGUI_PASSWORD" ]; then
  WGUI_PASSWORD="$DEFAULT_PASSWORD"
  echo "Usando contraseña por defecto: ${DEFAULT_PASSWORD}"
fi

# Crear directorios para persistencia
echo
echo "Creando directorios de persistencia..."
if [ "$USE_SUDO_DOCKER" = true ]; then
  sudo mkdir -p "${WIREGUARD_DIR}"
  sudo mkdir -p "${WIREGUARD_CONF_DIR}"
  sudo chown -R $USER:$USER "${WIREGUARD_DIR}"
else
  mkdir -p "${WIREGUARD_DIR}"
  mkdir -p "${WIREGUARD_CONF_DIR}"
fi
echo "✓ Directorios creados:"
echo "  • ${WIREGUARD_DIR}"
echo "  • ${WIREGUARD_CONF_DIR}"

# Descargar imagen de WireGuard-UI
echo
echo "Descargando imagen de WireGuard-UI..."
run_docker pull "$IMAGE_NAME"

# Crear y ejecutar contenedor WireGuard-UI
echo
echo "Creando contenedor WireGuard-UI..."
run_docker run -d \
  --name $CONTAINER_NAME \
  --cap-add=NET_ADMIN \
  --cap-add=SYS_MODULE \
  --sysctl="net.ipv4.conf.all.src_valid_mark=1" \
  --sysctl="net.ipv4.ip_forward=1" \
  -e WGUI_USERNAME="$WGUI_USERNAME" \
  -e WGUI_PASSWORD="$WGUI_PASSWORD" \
  -e WGUI_ENDPOINT_ADDRESS="$PUBLIC_IP" \
  -e WGUI_DNS="1.1.1.1,1.0.0.1" \
  -e WGUI_MTU="1420" \
  -e WGUI_PERSISTENT_KEEPALIVE="25" \
  -e WGUI_FORWARD_MARK="0xca6c" \
  -e WGUI_CONFIG_FILE_PATH="/etc/wireguard/wg0.conf" \
  -p ${WEB_PORT}:5000 \
  -p 51820:51820/udp \
  -v ${WIREGUARD_DIR}:/app/db \
  -v ${WIREGUARD_CONF_DIR}:/etc/wireguard \
  --restart unless-stopped \
  "$IMAGE_NAME"

# Esperar a que WireGuard-UI esté listo
echo
echo "Esperando a que WireGuard-UI inicie (10 segundos)..."
sleep 10

# Verificar que el contenedor está corriendo
echo
if run_docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  echo "✓ WireGuard-UI está corriendo correctamente."
else
  echo "✗ Error: WireGuard-UI no está corriendo."
  echo "Logs del contenedor:"
  run_docker logs --tail 50 "$CONTAINER_NAME"
  exit 1
fi

# Obtener IP local
LOCAL_IP=$(hostname -I | awk '{print $1}')

# Información final
echo
echo "═══════════════════════════════════════════════════════════"
echo "  ✓ WireGuard-UI instalado exitosamente"
echo "═══════════════════════════════════════════════════════════"
echo
echo "Información de acceso:"
echo " • Web UI:      http://${LOCAL_IP}:${WEB_PORT}"
echo " • Usuario:     ${WGUI_USERNAME}"
echo " • Contraseña:  ${WGUI_PASSWORD}"
echo " • Endpoint:    ${PUBLIC_IP}:${DEFAULT_PORT}"
echo
echo "Próximos pasos:"
echo "  1. Accede a la Web UI desde tu navegador"
echo "  2. Configura el servidor WireGuard (si no está ya configurado)"
echo "  3. Añade clientes desde la interfaz"
echo "  4. ⚠ IMPORTANTE: Configura port forwarding en tu router"
echo "     Puerto: ${DEFAULT_PORT}/UDP → ${LOCAL_IP}:${DEFAULT_PORT}"
echo
echo "Comandos útiles:"
echo "  • Ver logs:       docker logs ${CONTAINER_NAME}"
echo "  • Reiniciar:      docker restart ${CONTAINER_NAME}"
echo "  • Ver estado WG:  sudo wg show"
echo
echo "═══════════════════════════════════════════════════════════"

exit 0