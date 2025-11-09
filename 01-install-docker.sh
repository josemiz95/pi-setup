#!/usr/bin/env bash
set -euo pipefail

# 01-install-docker.sh
# Verifica e instala Docker si es necesario

DOCKER_DOC_URL="https://docs.docker.com/engine/install/"

echo "Verificando instalación de Docker..."

# Verificar si Docker ya está instalado
if command -v docker >/dev/null 2>&1; then
  echo "✓ Docker ya está instalado."
  docker --version
  
  # Verificar si necesita sudo
  if docker info >/dev/null 2>&1; then
    echo "✓ Docker funciona sin sudo."
  else
    echo "⚠ Docker requiere sudo. Verificando permisos..."
    
    # Intentar añadir usuario al grupo docker
    if ! groups | grep -q docker; then
      echo "Añadiendo usuario actual al grupo 'docker'..."
      sudo usermod -aG docker "$USER"
      echo "⚠ Necesitarás cerrar sesión y volver a entrar para que los cambios surtan efecto."
      echo "  O ejecuta: newgrp docker"
    fi
  fi
  
  exit 0
fi

# Docker no está instalado, proceder con la instalación
echo "Docker no está instalado. Iniciando instalación..."

# Detectar sistema operativo
if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS=$ID
else
  echo "✗ No se pudo detectar el sistema operativo."
  exit 1
fi

echo "Sistema operativo detectado: $OS"

# Instalación según el sistema operativo
case "$OS" in
  debian|ubuntu|raspbian)
    echo "Instalando Docker para Debian/Ubuntu/Raspbian..."
    
    # Actualizar repositorios
    sudo apt-get update
    
    # Instalar dependencias
    sudo apt-get install -y \
      ca-certificates \
      curl \
      gnupg \
      lsb-release
    
    # Añadir clave GPG oficial de Docker
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/$OS/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Añadir repositorio de Docker
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Instalar Docker Engine
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Añadir usuario al grupo docker
    sudo usermod -aG docker "$USER"
    
    echo "✓ Docker instalado correctamente."
    echo "⚠ Necesitarás cerrar sesión y volver a entrar para usar Docker sin sudo."
    ;;
    
  *)
    echo "✗ Sistema operativo no soportado automáticamente: $OS"
    echo "Por favor, instala Docker manualmente siguiendo: $DOCKER_DOC_URL"
    exit 1
    ;;
esac

# Verificar instalación
if command -v docker >/dev/null 2>&1; then
  echo
  echo "✓ Docker instalado exitosamente:"
  docker --version
  
  # Iniciar y habilitar el servicio Docker
  sudo systemctl start docker
  sudo systemctl enable docker
  
  echo
  echo "Servicio Docker iniciado y habilitado."
else
  echo "✗ Error: Docker no se instaló correctamente."
  exit 1
fi

exit 0