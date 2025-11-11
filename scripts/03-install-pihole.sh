#!/usr/bin/env bash
set -euo pipefail

# 03-install-pihole.sh
# Instala Pi-hole en Docker con configuración de red local

CONTAINER_NAME="pihole"
IMAGE_NAME="pihole/pihole:latest"
PIHOLE_DIR="${HOME}/.pihole"
NETWORK_NAME="homelab"
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
echo
echo "═══════════════════════════════════════════════════════════"
echo "  Configuración de contraseña para Pi-hole"
echo "═══════════════════════════════════════════════════════════"
echo
echo "Por favor, introduce una contraseña para el panel de administración"
echo "de Pi-hole, o presiona Enter para usar la contraseña por defecto."
echo
echo "Contraseña por defecto: ${DEFAULT_PASSWORD}"
echo

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

# Crear y ejecutar contenedor Pi-hole (sin contraseña inicial)
echo
echo "Creando contenedor Pi-hole..."
run_docker run -d \
  --name $CONTAINER_NAME \
  -p 53:53/tcp -p 53:53/udp \
  -p 80:80/tcp -p 443:443/tcp \
  -e TZ='Europe/Madrid' \
  -e FTLCONF_webserver_api_password='josemi123' \
  -e FTLCONF_dns_listeningMode='ALL' \
  -v ${PIHOLE_DIR}/etc-pihole:/etc/pihole \
  --cap-add=NET_ADMIN --cap-add=SYS_TIME --cap-add=SYS_NICE \
  --restart unless-stopped \
  "$IMAGE_NAME"

echo "✓ Contenedor Pi-hole creado."

# Esperar a que Pi-hole esté listo
echo
echo "Esperando a que Pi-hole inicie completamente..."
echo "(Esto puede tardar hasta 60 segundos)"

# Esperar hasta 60 segundos a que Pi-hole esté completamente listo
READY=false
for i in {1..60}; do
  # Verificar que el proceso lighttpd esté corriendo (indica que está listo)
  if run_docker exec "$CONTAINER_NAME" pgrep lighttpd >/dev/null 2>&1; then
    echo "✓ Pi-hole ha iniciado correctamente (después de $i segundos)."
    READY=true
    break
  fi
  
  if [ $((i % 10)) -eq 0 ]; then
    echo "  Esperando... ($i/60 segundos)"
  fi
  
  sleep 1
done

if [ "$READY" = false ]; then
  echo "⚠ Pi-hole tardó más de lo esperado en iniciar."
  echo "Intentando configurar la contraseña de todos modos..."
fi

# Espera adicional de seguridad
sleep 5

# Configurar contraseña usando pihole setpassword
echo
echo "Configurando contraseña de Pi-hole..."
echo "Intentando método 1: pihole -a -p"

# Método 1: usando pihole -a -p (método estándar)
if run_docker exec "$CONTAINER_NAME" pihole setpassword "$PIHOLE_PASSWORD" >/dev/null 2>&1; then
      echo "✓ Contraseña configurada correctamente (método 3)."
      PASSWORD_SET=true
fi
  
# Si no se pudo configurar, dar instrucciones
if [ "$PASSWORD_SET" = false ]; then
  echo
  echo "✗ No se pudo configurar la contraseña automáticamente."
  echo
  echo "Por favor, configúrala manualmente ejecutando:"
  if [ "$USE_SUDO_DOCKER" = true ]; then
    echo "  sudo docker exec -it $CONTAINER_NAME pihole -a -p"
  else
    echo "  docker exec -it $CONTAINER_NAME pihole -a -p"
  fi
  echo
  echo "Y luego introduce: $PIHOLE_PASSWORD"
  echo
  echo "O desde el panel web:"
  echo "  1. Ve a http://${LOCAL_IP:-tu-ip}:5353/admin"
  echo "  2. Click en 'Settings' > 'Set Web Password'"
  echo "  3. Introduce: $PIHOLE_PASSWORD"
fi

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
if [ "$PASSWORD_SET" = true ]; then
  echo " • Contraseña:  ${PIHOLE_PASSWORD} ✓"
else
  echo " • Contraseña:  ${PIHOLE_PASSWORD} ⚠ (requiere configuración manual)"
fi
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
if [ "$PASSWORD_SET" = true ]; then
  echo "⚠ IMPORTANTE: Guarda esta contraseña en un lugar seguro:"
  echo "   ${PIHOLE_PASSWORD}"
else
  echo "⚠ RECUERDA: Debes configurar la contraseña manualmente."
  echo "   Contraseña deseada: ${PIHOLE_PASSWORD}"
fi
echo
echo "═══════════════════════════════════════════════════════════"

exit 0