#!/usr/bin/env bash
set -euo pipefail

# 03-install-pihole.sh
# Instala Pi-hole en Docker con configuración de red local

CONTAINER_NAME="pihole"
IMAGE_NAME="pihole/pihole:latest"
PIHOLE_DIR="${HOME}/.pihole"
DEFAULT_PASSWORD="admin123"

echo "═══════════════════════════════════════════════════════════"
echo "  Instalación de Pi-hole en Docker"
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

# Verificar si Pi-hole ya está instalado
if run_docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  echo "⚠ El contenedor '${CONTAINER_NAME}' ya existe."
  
  read -p "¿Deseas eliminarlo y reinstalar? (s/n): " response < /dev/tty
  if [[ ! "$response" =~ ^[Ss]$ ]]; then
    echo "Cancelando instalación de Pi-hole."
    exit 0
  fi
  
  echo "Eliminando contenedor existente..."
  run_docker stop "$CONTAINER_NAME" 2>/dev/null || true
  run_docker rm "$CONTAINER_NAME" 2>/dev/null || true
fi

# Pedir contraseña al usuario
read -p "Contraseña (Enter para usar '${DEFAULT_PASSWORD}'): " PIHOLE_PASSWORD < /dev/tty

# Si no se introduce contraseña, usar la por defecto
if [ -z "$PIHOLE_PASSWORD" ]; then
  PIHOLE_PASSWORD="$DEFAULT_PASSWORD"
  echo "Usando contraseña por defecto: ${DEFAULT_PASSWORD}"
else
  echo "Contraseña personalizada establecida."
fi

# Crear directorios para persistencia
echo
echo "Creando directorios de persistencia..."
mkdir -p "${PIHOLE_DIR}/etc-pihole"
mkdir -p "${PIHOLE_DIR}/etc-dnsmasq.d"
echo "✓ Directorios creados en: ${PIHOLE_DIR}"

# Descargar imagen de Pi-hole
echo
echo "Descargando imagen de Pi-hole..."
run_docker pull "$IMAGE_NAME"

# Crear y ejecutar contenedor Pi-hole (sin contraseña inicial)
echo
echo "Creando contenedor Pi-hole..."
run_docker run -d \
  --name $CONTAINER_NAME \
  -p 53:53/tcp -p 53:53/udp \
  -p 80:80/tcp -p 443:443/tcp \
  -e TZ='Europe/Madrid' \
  -e FTLCONF_webserver_api_password="$PIHOLE_PASSWORD" \
  -e FTLCONF_dns_listeningMode='ALL' \
  -v ${PIHOLE_DIR}/etc-pihole:/etc/pihole \
  --cap-add=NET_ADMIN --cap-add=SYS_TIME --cap-add=SYS_NICE \
  --restart unless-stopped \
  "$IMAGE_NAME"

# Esperar a que Pi-hole esté listo
echo
echo "Esperando a que Pi-hole inicie (10 segundos)..."
sleep 10

# Verificar que el contenedor está corriendo
echo
if run_docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  echo "✓ Pi-hole está corriendo correctamente."
else
  echo "✗ Error: Pi-hole no está corriendo."
  echo "Logs del contenedor:"
  run_docker logs --tail 50 "$CONTAINER_NAME"
  exit 1
fi

# Obtener IP local
LOCAL_IP=$(hostname -I | awk '{print $1}')

# Información final
echo
echo "═══════════════════════════════════════════════════════════"
echo "  ✓ Pi-hole instalado exitosamente"
echo "═══════════════════════════════════════════════════════════"
echo
echo "Información de acceso:"
echo " • Admin UI:    http://${LOCAL_IP}:5353/admin"
echo " • Contraseña:  ${PIHOLE_PASSWORD} ✓"
echo " • DNS Server:  ${LOCAL_IP}:53"
echo
echo "Para usar Pi-hole como DNS en tu red:"
echo "  1. Accede a la configuración de tu router"
echo "  2. Cambia el DNS primario a: ${LOCAL_IP}"
echo
echo "═══════════════════════════════════════════════════════════"

exit 0