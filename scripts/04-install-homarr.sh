#!/usr/bin/env bash
set -euo pipefail

# 04-install-homarr.sh
# Instala Homarr en Docker en el puerto 80 como index principal

CONTAINER_NAME="homarr"
IMAGE_NAME="ghcr.io/homarr-labs/homarr:latest"
HOMARR_DIR="${HOME}/.homarr"

echo "═══════════════════════════════════════════════════════════"
echo "  Instalación de Homarr Dashboard"
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

# Verificar si Homarr ya está instalado
if run_docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  echo "⚠ El contenedor '${CONTAINER_NAME}' ya existe."
  
  if [ "${YES_TO_ALL:-false}" = false ]; then
    read -p "¿Deseas eliminarlo y reinstalar? (s/n): " response
    if [[ ! "$response" =~ ^[Ss]$ ]]; then
      echo "Cancelando instalación de Homarr."
      exit 0
    fi
  fi
  
  echo "Eliminando contenedor existente..."
  run_docker stop "$CONTAINER_NAME" 2>/dev/null || true
  run_docker rm "$CONTAINER_NAME" 2>/dev/null || true
fi

# Verificar si el puerto 80 está disponible
HTTP_PORT=80

if command -v netstat >/dev/null 2>&1; then
  if netstat -tuln | grep -q ":80 "; then
    echo "⚠ Advertencia: El puerto 80 está en uso, se procedera a usar el puerto 7575."
    HTTP_PORT=7575
  fi
fi

# Generar SECRET_ENCRYPTION_KEY
echo
echo "Generando clave de encriptación para Homarr..."
if command -v openssl >/dev/null 2>&1; then
  SECRET_ENCRYPTION_KEY=$(openssl rand -hex 32)
  echo "✓ Clave generada correctamente."
else
  echo "⚠ openssl no encontrado. Usando clave generada aleatoriamente."
  SECRET_ENCRYPTION_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 64 | head -n 1)
fi

# Crear directorios para persistencia
echo
echo "Creando directorios de persistencia..."
mkdir -p "${HOMARR_DIR}/data"
mkdir -p "${HOMARR_DIR}/configs"
mkdir -p "${HOMARR_DIR}/icons"
echo "✓ Directorios creados en: ${HOMARR_DIR}"

# Descargar imagen de Homarr
echo
echo "Descargando imagen de Homarr..."
run_docker pull "$IMAGE_NAME"

# Detectar arquitectura
ARCH=$(uname -m)
PLATFORM=""
case "$ARCH" in
  aarch64|arm64)
    PLATFORM="--platform linux/arm64"
    echo "Arquitectura detectada: ARM64"
    ;;
  x86_64|amd64)
    PLATFORM="--platform linux/amd64"
    echo "Arquitectura detectada: AMD64"
    ;;
  *)
    echo "⚠ Arquitectura no reconocida: $ARCH. Continuando sin especificar platform."
    ;;
esac

# Crear y ejecutar contenedor Homarr
echo
echo "Creando contenedor Homarr..."
run_docker run -d \
  --name "$CONTAINER_NAME" \
  $PLATFORM \
  -e TZ="Europe/Madrid" \
  -e SECRET_ENCRYPTION_KEY="$SECRET_ENCRYPTION_KEY" \
  -v "${HOMARR_DIR}/data:/app/data" \
  -v "${HOMARR_DIR}/configs:/app/configs" \
  -v "${HOMARR_DIR}/icons:/app/public/icons" \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -p "${HTTP_PORT}:7575" \
  --restart unless-stopped \
  "$IMAGE_NAME"

# Esperar a que Homarr esté listo
echo
echo "Esperando a que Homarr inicie (10 segundos)..."
sleep 10

# Verificar que el contenedor está corriendo
if run_docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  echo "✓ Homarr está corriendo correctamente."
else
  echo "✗ Error: Homarr no está corriendo."
  echo "Logs del contenedor:"
  run_docker logs "$CONTAINER_NAME"
  exit 1
fi

# Obtener IP local
LOCAL_IP=$(hostname -I | awk '{print $1}')

# Información final
echo
echo "═══════════════════════════════════════════════════════════"
echo "  ✓ Homarr instalado exitosamente"
echo "═══════════════════════════════════════════════════════════"
echo
echo "Información de acceso:"
if [ "$HTTP_PORT" = "80" ]; then
  echo " • Dashboard:   http://${LOCAL_IP}"
  echo "                (Puerto 80 - Index principal)"
else
  echo " • Dashboard:   http://${LOCAL_IP}:${HTTP_PORT}"
fi
echo
echo "Homarr tiene acceso al socket de Docker para monitorizar"
echo "los contenedores en tu sistema."
echo
echo "═══════════════════════════════════════════════════════════"

exit 0