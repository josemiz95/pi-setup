#!/usr/bin/env bash
set -euo pipefail

# 03-install-pihole.sh
# Instala Pi-hole en Docker con configuración de red local

CONTAINER_NAME="pihole"
IMAGE_NAME="pihole/pihole:latest"
PIHOLE_DIR="${HOME}/.pihole"
NETWORK_NAME="homelab"

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
  
  if [ "${YES_TO_ALL:-false}" = false ]; then
    read -p "¿Deseas eliminarlo y reinstalar? (s/n): " response
    if [[ ! "$response" =~ ^[Ss]$ ]]; then
      echo "Cancelando instalación de Pi-hole."
      exit 0
    fi
  fi
  
  echo "Eliminando contenedor existente..."
  run_docker stop "$CONTAINER_NAME" 2>/dev/null || true
  run_docker rm "$CONTAINER_NAME" 2>/dev/null || true
fi

# Pedir contraseña al usuario
if [ "${YES_TO_ALL:-false}" = true ]; then
  # Si es automático, usar contraseña por defecto o variable de entorno
  PIHOLE_PASSWORD="${PIHOLE_PASSWORD:-admin123}"
  echo "Usando contraseña por defecto para modo automático."
else
  echo
  echo "Por favor, introduce la contraseña para Pi-hole:"
  read -rsp "Contraseña: " PIHOLE_PASSWORD
  echo
  
  if [ -z "$PIHOLE_PASSWORD" ]; then
    echo "✗ Error: La contraseña no puede estar vacía."
    exit 1
  fi
fi

# Crear directorios para persistencia
echo
echo "Creando directorios de persistencia..."
mkdir -p "${PIHOLE_DIR}/etc-pihole"
mkdir -p "${PIHOLE_DIR}/etc-dnsmasq.d"
echo "✓ Directorios creados en: ${PIHOLE_DIR}"

# Crear red Docker si no existe
echo
echo "Configurando red Docker '${NETWORK_NAME}'..."
if ! run_docker network ls --format '{{.Name}}' | grep -q "^${NETWORK_NAME}$"; then
  run_docker network create \
    --driver bridge \
    --subnet 10.0.1.0/24 \
    --gateway 10.0.1.1 \
    "${NETWORK_NAME}"
  echo "✓ Red '${NETWORK_NAME}' creada."
else
  echo "✓ Red '${NETWORK_NAME}' ya existe."
fi

# Descargar imagen de Pi-hole
echo
echo "Descargando imagen de Pi-hole..."
run_docker pull "$IMAGE_NAME"

# Crear y ejecutar contenedor Pi-hole
echo
echo "Creando contenedor Pi-hole..."
run_docker run -d \
  --name "$CONTAINER_NAME" \
  --hostname pihole \
  --network "$NETWORK_NAME" \
  --ip 10.0.1.3 \
  -e TZ="Europe/Madrid" \
  -e WEBPASSWORD="$PIHOLE_PASSWORD" \
  -e DNSMASQ_LISTENING=all \
  -v "${PIHOLE_DIR}/etc-pihole:/etc/pihole" \
  -v "${PIHOLE_DIR}/etc-dnsmasq.d:/etc/dnsmasq.d" \
  -p 53:53/tcp \
  -p 53:53/udp \
  -p 5353:80/tcp \
  --restart unless-stopped \
  --cap-add NET_ADMIN \
  "$IMAGE_NAME"

echo "✓ Contenedor Pi-hole creado."

# Esperar a que Pi-hole esté listo
echo
echo "Esperando a que Pi-hole inicie (15 segundos)..."
sleep 15

# Verificar que el contenedor está corriendo
if run_docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  echo "✓ Pi-hole está corriendo correctamente."
else
  echo "✗ Error: Pi-hole no está corriendo."
  echo "Logs del contenedor:"
  run_docker logs "$CONTAINER_NAME"
  exit 1
fi

# Forzar cambio de contraseña en Pi-hole
echo
echo "Configurando contraseña de Pi-hole..."
if run_docker exec "$CONTAINER_NAME" pihole setpassword "$PIHOLE_PASSWORD" >/dev/null 2>&1; then
  echo "✓ Contraseña de Pi-hole configurada correctamente."
else
  echo "⚠ No se pudo actualizar la contraseña automáticamente."
  echo "Puedes hacerlo manualmente con:"
  if [ "$USE_SUDO_DOCKER" = true ]; then
    echo "  sudo docker exec -it $CONTAINER_NAME pihole setpassword"
  else
    echo "  docker exec -it $CONTAINER_NAME pihole setpassword"
  fi
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
echo " • Contraseña:  (la que acabas de configurar)"
echo " • DNS Server:  ${LOCAL_IP}:53"
echo
echo "Configuración de red:"
echo " • Red Docker:  ${NETWORK_NAME}"
echo " • IP interna:  10.0.1.3"
echo
echo "Para usar Pi-hole como DNS en tu red:"
echo "  1. Accede a la configuración de tu router"
echo "  2. Cambia el DNS primario a: ${LOCAL_IP}"
echo
echo "═══════════════════════════════════════════════════════════"

exit 0