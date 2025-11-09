# Instalador Modular para Raspberry Pi

Sistema de instalación modular para servicios en Docker: Pi-hole, Homarr y más.

## 📋 Requisitos

- Raspberry Pi (preferiblemente 64-bit) o servidor Linux
- Sistema operativo: Debian/Ubuntu/Raspbian
- Conexión a Internet
- Acceso sudo

## 🚀 Instalación Rápida

### Método 1: Ejecución directa desde GitHub

```bash
curl -s https://raw.githubusercontent.com/josemiz95/pi-setup/refs/heads/main/install.sh | bash
```

### Método 2: Clonar repositorio

```bash
git clone https://github.com/josemiz95/pi-setup
cd pi-setup
chmod +x install.sh
./install.sh
```

## 🎯 Modos de Uso

### Modo Interactivo (por defecto)
```bash
./install.sh
```
El script preguntará para cada paso si deseas instalarlo.

### Modo Automático (sin preguntas)
```bash
./install.sh -y
# o
./install.sh --yes
```
Instala todos los componentes sin preguntar.

## 📦 Componentes que se Instalan

### 1. Docker
- **Script:** `scripts/01-install-docker.sh`
- Verifica si Docker está instalado
- Instala Docker Engine si es necesario
- Configura permisos de usuario

### 2. VPN (Próximamente)
- **Script:** `scripts/02-install-vpn.sh`
- Actualmente es un placeholder
- Será implementado en futuras versiones

### 3. Pi-hole
- **Script:** `scripts/03-install-pihole.sh`
- Servidor DNS con bloqueo de publicidad
- Puerto web: **5353** (admin: `/admin`)
- Puerto DNS: **53**
- Requiere contraseña personalizada
- Red: `homelab` (10.0.1.0/24)

### 4. Homarr
- **Script:** `scripts/04-install-homarr.sh`
- Dashboard de gestión de servicios
- Puerto: **80** (index principal) o **7575** si el 80 está ocupado
- Monitorización de contenedores Docker
- Red: `homelab` (10.0.1.0/24)

## 🌐 Estructura de Red Docker

Todos los servicios se despliegan en la red `homelab`:

- **Subred:** 10.0.1.0/24
- **Gateway:** 10.0.1.1
- **Pi-hole:** 10.0.1.3
- **Homarr:** 10.0.1.4

## 📂 Estructura del Proyecto

```
.
├── install.sh                    # Script orquestador principal
├── scripts/
│   ├── 01-install-docker.sh     # Instalación de Docker
│   ├── 02-install-vpn.sh        # Instalación de VPN (placeholder)
│   ├── 03-install-pihole.sh     # Instalación de Pi-hole
│   └── 04-install-homarr.sh     # Instalación de Homarr
└── README.md                     # Este archivo
```

## 🔧 Configuración Post-Instalación

### Pi-hole
1. Accede a: `http://<IP-RPI>:5353/admin`
2. Inicia sesión con la contraseña configurada
3. Configura tu router para usar la IP de tu RPi como DNS

### Homarr
1. Accede a: `http://<IP-RPI>` o `http://<IP-RPI>:7575`
2. Configura los widgets y servicios desde la interfaz
3. Añade tus servicios locales para monitorizarlos

## 📝 Datos Persistentes

Los datos se almacenan en:

- **Pi-hole:** `~/.pihole/`
- **Homarr:** `~/.homarr/`

## 🛠️ Gestión de Servicios

### Ver servicios corriendo
```bash
docker ps
```

### Ver logs de un servicio
```bash
docker logs pihole
docker logs homarr
```

### Reiniciar un servicio
```bash
docker restart pihole
docker restart homarr
```

### Detener un servicio
```bash
docker stop pihole
docker stop homarr
```

### Eliminar un servicio
```bash
docker stop pihole && docker rm pihole
docker stop homarr && docker rm homarr
```

## 🔒 Seguridad

- Pi-hole requiere contraseña personalizada (se solicita durante la instalación)
- Homarr genera automáticamente una clave de encriptación
- Los servicios usan la red interna de Docker
- El acceso al socket de Docker es de solo lectura para Homarr

## 🐛 Solución de Problemas

### Docker requiere sudo
```bash
# Añadir tu usuario al grupo docker
sudo usermod -aG docker $USER
# Cerrar sesión y volver a entrar, o ejecutar:
newgrp docker
```

### Puerto 80 ocupado
El instalador de Homarr detecta automáticamente si el puerto 80 está ocupado y usa el 7575 como alternativa.

### Ver logs de instalación
Los scripts muestran información detallada durante la ejecución. Si hay errores, revisa:
```bash
docker logs <nombre-contenedor>
```

## 🔄 Añadir Nuevos Servicios

Para añadir un nuevo servicio:

1. Crea un nuevo script: `scripts/05-install-nuevo-servicio.sh`
2. Usa como plantilla los scripts existentes
3. Añade el nuevo paso en `install.sh` siguiendo el patrón existente
4. Asegúrate de usar la red `homelab` y asignar una IP fija

## 📞 Soporte

Para reportar problemas o sugerir mejoras, abre un issue en el repositorio.

## 📄 Licencia

Este proyecto es de código abierto. Siéntete libre de usarlo y modificarlo.

---

**Nota:** Este instalador está optimizado para Raspberry Pi pero debería funcionar en cualquier sistema Debian/Ubuntu compatible.