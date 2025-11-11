#!/usr/bin/env bash
set -euo pipefail

# install.sh - Script orquestador principal
# Ejecuta los sub-scripts de instalación de forma modular

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="${SCRIPT_DIR}/scripts"

# URL base del repositorio de GitHub
GITHUB_REPO="https://raw.githubusercontent.com/josemiz95/pi-setup/main"
DOWNLOAD_SCRIPTS=false

# Detectar si estamos ejecutando desde curl | bash
if [ ! -d "$SCRIPTS_DIR" ]; then
  echo "Detectado modo de ejecución remota. Descargando scripts..."
  DOWNLOAD_SCRIPTS=true
  mkdir -p "$SCRIPTS_DIR"
fi

# Colores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Arrays para rastrear instalaciones
declare -a INSTALLED_SERVICES=()
declare -a FAILED_SERVICES=()
declare -a SKIPPED_SERVICES=()

# Función para mostrar banner
show_banner() {
  echo
  echo "════════════════════════════════════════════════════════════"
  echo "  Instalador Modular - Raspberry Pi Services"
  echo "  Docker + VPN + Pi-hole + Homarr"
  echo "════════════════════════════════════════════════════════════"
  echo
}

# Función para preguntar al usuario (compatible con curl | bash)
ask_user() {
  local prompt="$1"
  
  while true; do
    # Leer desde /dev/tty para que funcione con curl | bash
    read -p "$prompt (s/n): " response < /dev/tty
    case "$response" in
      [Ss]* ) return 0;;
      [Nn]* ) return 1;;
      * ) echo "Por favor responde 's' o 'n'.";;
    esac
  done
}

# Función para descargar un sub-script si es necesario
download_subscript() {
  local script_name="$1"
  local script_path="${SCRIPTS_DIR}/${script_name}"
  
  if [ "$DOWNLOAD_SCRIPTS" = true ]; then
    echo "Descargando ${script_name}..."
    if curl -fsSL "${GITHUB_REPO}/scripts/${script_name}" -o "$script_path"; then
      chmod +x "$script_path"
      return 0
    else
      echo -e "${RED}✗${NC} Error al descargar ${script_name}"
      return 1
    fi
  fi
  return 0
}

# Función para ejecutar un sub-script
run_subscript() {
  local script_name="$1"
  local service_name="$2"
  local script_path="${SCRIPTS_DIR}/${script_name}"
  
  # Descargar si es necesario
  if ! download_subscript "$script_name"; then
    FAILED_SERVICES+=("$service_name")
    return 1
  fi
  
  if [ ! -f "$script_path" ]; then
    echo -e "${RED}✗${NC} Error: No se encuentra el script $script_name"
    FAILED_SERVICES+=("$service_name")
    return 1
  fi
  
  chmod +x "$script_path"
  if bash "$script_path"; then
    INSTALLED_SERVICES+=("$service_name")
    return 0
  else
    FAILED_SERVICES+=("$service_name")
    return 1
  fi
}

# Función para verificar contenedores Docker
check_docker_containers() {
  local containers=()
  
  # Detectar si necesita sudo
  if docker ps >/dev/null 2>&1; then
    DOCKER_CMD="docker"
  elif sudo docker ps >/dev/null 2>&1; then
    DOCKER_CMD="sudo docker"
  else
    return
  fi
  
  # Buscar contenedores específicos
  for container in pihole homarr wg-easy; do
    if $DOCKER_CMD ps --format '{{.Names}}' 2>/dev/null | grep -q "^${container}$"; then
      containers+=("$container")
    fi
  done
  
  echo "${containers[@]}"
}

# Función para mostrar resumen final mejorado
show_final_summary() {
  echo
  echo "════════════════════════════════════════════════════════════"
  echo -e "${BLUE}  📊 Resumen de la Instalación${NC}"
  echo "════════════════════════════════════════════════════════════"
  echo
  
  # Servicios instalados
  if [ ${#INSTALLED_SERVICES[@]} -gt 0 ]; then
    echo -e "${GREEN}✓ Servicios instalados correctamente:${NC}"
    for service in "${INSTALLED_SERVICES[@]}"; do
      echo "  • $service"
    done
    echo
  fi
  
  # Servicios omitidos
  if [ ${#SKIPPED_SERVICES[@]} -gt 0 ]; then
    echo -e "${YELLOW}⊘ Servicios omitidos:${NC}"
    for service in "${SKIPPED_SERVICES[@]}"; do
      echo "  • $service"
    done
    echo
  fi
  
  # Servicios con errores
  if [ ${#FAILED_SERVICES[@]} -gt 0 ]; then
    echo -e "${RED}✗ Servicios con errores:${NC}"
    for service in "${FAILED_SERVICES[@]}"; do
      echo "  • $service"
    done
    echo
  fi
  
  # Verificar contenedores corriendo
  local running_containers=($(check_docker_containers))
  
  if [ ${#running_containers[@]} -gt 0 ]; then
    echo "════════════════════════════════════════════════════════════"
    echo -e "${GREEN}  🐳 Contenedores Docker en ejecución${NC}"
    echo "════════════════════════════════════════════════════════════"
    echo
    
    local local_ip=$(hostname -I | awk '{print $1}')
    
    for container in "${running_containers[@]}"; do
      case "$container" in
        pihole)
          echo -e "${GREEN}●${NC} ${BLUE}pihole${NC}"
          echo "  └─ Admin UI:  http://${local_ip}:5353/admin"
          echo "  └─ DNS:       ${local_ip}:53"
          ;;
        homarr)
          echo -e "${GREEN}●${NC} ${BLUE}homarr${NC}"
          # Verificar en qué puerto está corriendo
          if docker ps 2>/dev/null | grep homarr | grep -q "0.0.0.0:80"; then
            echo "  └─ Dashboard: http://${local_ip}"
          elif docker ps 2>/dev/null | grep homarr | grep -q "0.0.0.0:7575"; then
            echo "  └─ Dashboard: http://${local_ip}:7575"
          else
            echo "  └─ Dashboard: Verificar puerto con 'docker ps'"
          fi
          ;;
        wg-easy)
          echo -e "${GREEN}●${NC} ${BLUE}wg-easy${NC}"
          echo "  └─ Admin UI:  http://${local_ip}:51821"
          echo "  └─ VPN Port:  ${local_ip}:51820/udp"
          ;;
      esac
      echo
    done
    
    echo "════════════════════════════════════════════════════════════"
    echo "  📝 Comandos útiles"
    echo "════════════════════════════════════════════════════════════"
    echo
    echo "Ver logs de un contenedor:"
    echo "  docker logs <nombre-contenedor>"
    echo
    echo "Reiniciar un contenedor:"
    echo "  docker restart <nombre-contenedor>"
    echo
    echo "Ver todos los contenedores:"
    echo "  docker ps -a"
    echo
  fi
  
  echo "════════════════════════════════════════════════════════════"
  
  # Mensaje final según el resultado
  if [ ${#FAILED_SERVICES[@]} -eq 0 ]; then
    echo -e "${GREEN}  ✓ Instalación completada exitosamente${NC}"
  else
    echo -e "${YELLOW}  ⚠ Instalación completada con algunas advertencias${NC}"
  fi
  echo "════════════════════════════════════════════════════════════"
  echo
}

# ═══════════════════════════════════════════════════════════
# INICIO DEL SCRIPT PRINCIPAL
# ═══════════════════════════════════════════════════════════

show_banner

echo "Iniciando proceso de instalación..."
echo

# ───────────────────────────────────────────────────────────
# PASO 1: Instalación de Docker
# ───────────────────────────────────────────────────────────
echo -e "${YELLOW}[PASO 1/4]${NC} Verificación e instalación de Docker"
if ask_user "¿Deseas verificar/instalar Docker?"; then
  if run_subscript "01-install-docker.sh" "Docker"; then
    echo -e "${GREEN}✓${NC} Docker configurado correctamente"
  else
    echo -e "${RED}✗${NC} Error en la instalación de Docker"
    echo "No se puede continuar sin Docker. Abortando."
    show_final_summary
    exit 1
  fi
else
  echo "Saltando instalación de Docker..."
  SKIPPED_SERVICES+=("Docker")
fi
echo

# ───────────────────────────────────────────────────────────
# PASO 2: Instalación de VPN
# ───────────────────────────────────────────────────────────
echo -e "${YELLOW}[PASO 2/4]${NC} Instalación de VPN"
if ask_user "¿Deseas instalar VPN?"; then
  if run_subscript "02-install-vpn.sh" "VPN"; then
    echo -e "${GREEN}✓${NC} VPN configurada correctamente"
  else
    echo -e "${YELLOW}⚠${NC} Instalación de VPN completada con advertencias"
  fi
else
  echo "Saltando instalación de VPN..."
  SKIPPED_SERVICES+=("VPN")
fi
echo

# ───────────────────────────────────────────────────────────
# PASO 3: Instalación de Pi-hole
# ───────────────────────────────────────────────────────────
echo -e "${YELLOW}[PASO 3/4]${NC} Instalación de Pi-hole"
if ask_user "¿Deseas instalar Pi-hole?"; then
  if run_subscript "03-install-pihole.sh" "Pi-hole"; then
    echo -e "${GREEN}✓${NC} Pi-hole instalado correctamente"
  else
    echo -e "${RED}✗${NC} Error en la instalación de Pi-hole"
  fi
else
  echo "Saltando instalación de Pi-hole..."
  SKIPPED_SERVICES+=("Pi-hole")
fi
echo

# ───────────────────────────────────────────────────────────
# PASO 4: Instalación de Homarr
# ───────────────────────────────────────────────────────────
echo -e "${YELLOW}[PASO 4/4]${NC} Instalación de Homarr"
if ask_user "¿Deseas instalar Homarr?"; then
  if run_subscript "04-install-homarr.sh" "Homarr"; then
    echo -e "${GREEN}✓${NC} Homarr instalado correctamente"
  else
    echo -e "${RED}✗${NC} Error en la instalación de Homarr"
  fi
else
  echo "Saltando instalación de Homarr..."
  SKIPPED_SERVICES+=("Homarr")
fi
echo

# ───────────────────────────────────────────────────────────
# PASO 5: Limpieza de archivos temporales
# ───────────────────────────────────────────────────────────
echo "Limpiando archivos temporales..."
rm -rf /scripts 2>/dev/null || sudo rm -rf /scripts
echo "✓ Limpieza completada"

# ───────────────────────────────────────────────────────────
# RESUMEN FINAL MEJORADO
# ───────────────────────────────────────────────────────────
show_final_summary

exit 0