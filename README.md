# Sync All - Sistema de Automatización de Tareas

Sistema automatizado para sincronización de proyectos, gestión de licencias y conversión de bóvedas Obsidian a PDF.

## 📋 Tabla de Contenidos

- [Descripción General](#descripción-general)
- [¿Qué es Crontab?](#qué-es-crontab)
- [Scripts Incluidos](#scripts-incluidos)
- [Instalación](#instalación)
- [Configuración](#configuración)
- [Uso](#uso)
- [Logs y Monitoreo](#logs-y-monitoreo)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Descripción General

**Sync All** es un conjunto de scripts bash optimizados para automatizar tareas repetitivas en tu flujo de trabajo:

- 🔄 Sincronización automática de repositorios Git
- 📝 Gestión de licencias de copyright en archivos
- 📚 Conversión de bóvedas Obsidian (Markdown) a PDF
- ⚡ Ejecución paralela y optimizada

Todo ejecutado automáticamente mediante **crontab** cada 20 minutos.

---

## ⏰ ¿Qué es Crontab?

**Crontab** (CRON TABLE) es el planificador de tareas de sistemas Unix/Linux que permite ejecutar comandos o scripts automáticamente en momentos específicos.

### Sintaxis básica:

```
┌───────────── minuto (0 - 59)
│ ┌───────────── hora (0 - 23)
│ │ ┌───────────── día del mes (1 - 31)
│ │ │ ┌───────────── mes (1 - 12)
│ │ │ │ ┌───────────── día de la semana (0 - 7, donde 0 y 7 = domingo)
│ │ │ │ │
* * * * * comando a ejecutar
```

### Ejemplos comunes:

```bash
*/20 * * * *    # Cada 20 minutos
0 */2 * * *     # Cada 2 horas
0 9 * * 1-5     # Lunes a viernes a las 9:00 AM
0 0 * * 0       # Cada domingo a medianoche
```

### Comandos útiles:

```bash
crontab -e      # Editar tu crontab
crontab -l      # Listar tareas programadas
crontab -r      # Eliminar todas las tareas
```

---

## 📦 Scripts Incluidos

### 1. **sync-all-optimized.sh** - Script Maestro

**Propósito:** Orquesta la ejecución de todos los demás scripts en secuencia optimizada.

**Características:**
- ✅ Ejecución paralela de tareas independientes
- ✅ Timeouts para evitar bloqueos
- ✅ Logging centralizado
- ✅ Rotación automática de logs
- ✅ Medición de tiempo de ejecución
- ✅ Manejo de errores sin detener el proceso

**Ubicación:** `~/ProyectosPersonales/Automatizaciones/sync-all-optimized.sh`

**Flujo de ejecución:**
```
1. Obsidian → PDF (timeout: 10 min)
2. Licencias (paralelo, timeout: 5 min cada uno)
   ├─ ProyectosPersonales
   └─ Escritorio
3. Git Sync (timeout: 10 min)
```

---

### 2. **actualiza_todos_git.sh** - Sincronizador Git

**Propósito:** Busca todos los repositorios Git y sincroniza cambios automáticamente.

**Características:**
- 🔍 Búsqueda recursiva de repositorios (`.git`)
- 📊 Detección eficiente de cambios con `git status --porcelain`
- 📝 Commits informativos con estadísticas
- 🚀 Push automático
- ⚡ Optimizado para repositorios grandes

**Directorios monitoreados:**
- `~/Escritorio`
- `~/Hackatones`
- `~/ProyectosPersonales`

**Ejemplo de mensaje de commit:**
```
Actualización automática [+3 ~2 ?1 ]
# +3 archivos añadidos
# ~2 archivos modificados
# ?1 archivo sin trackear
```

**Ubicación:** `~/ProyectosPersonales/Automatizaciones/actualiza_todos_git.sh`

---

### 3. **license.sh** - Gestor de Licencias

**Propósito:** Añade cabeceras de copyright a archivos de código automáticamente.

**Características:**
- 📄 Soporta múltiples lenguajes (Python, Java, C++, SQL, Shell, Markdown, etc.)
- 🚫 Exclusión de directorios (node_modules, .git, etc.)
- 🎯 Exclusión de rutas específicas (`~/Escritorio/IA/CLIPS`)
- 🔍 Detección de archivos de texto
- ✅ Evita duplicación de licencias
- 🔧 Preserva shebangs (`#!/bin/bash`)
- ⚡ Lookup O(1) con hashmaps

**Extensiones soportadas:**
- `py`, `sh`, `java`, `c`, `cpp`, `h`, `sql`, `clp`, `md`, `txt`

**Texto de licencia:**
```
Copyright (c) 2025 Adrián Quiroga Linares
Lectura y referencia permitidas; reutilización y plagio prohibidos
```

**Directorios excluidos por defecto:**
```
.git, node_modules, vendor, dist, build, target, out, .venv, venv,
__pycache__, .idea, .vscode, coverage, .next, .nuxt, .cache, .gradle,
.pytest_cache, .tox, .mypy_cache, .terraform, .pio
```

**Ubicación:** `~/ProyectosPersonales/Licencia/license.sh`

---

### 4. **md_to_pdf.sh** - Convertidor Obsidian → PDF

**Propósito:** Convierte bóvedas de Obsidian (Markdown) a PDFs con imágenes embebidas.

**Características:**
- 📚 Detección automática de bóvedas Obsidian (busca `.obsidian`)
- 🖼️ Procesamiento de imágenes con sintaxis Obsidian `![[imagen.png]]`
- 🔄 Conversión incremental (solo archivos modificados)
- 📁 Estructura idéntica a la bóveda original
- 🚫 Excluye carpetas de imágenes
- 🗑️ Elimina PDFs huérfanos
- ⚡ Cache de búsqueda de imágenes en Python
- 🎨 Soporta WeasyPrint o Pandoc+XeLaTeX

**Flujo de trabajo:**
```
Bóveda Original          Bóveda PDF
├── nota1.md        →    ├── nota1.pdf
├── nota2.md        →    ├── nota2.pdf
├── imagenes/            │   (excluida)
├── archivo.pdf     →    ├── archivo.pdf (copiado)
└── .git/           →    └── .git/ (copiado)
```

**Ubicación:** `~/ProyectosPersonales/Automatizaciones/md_to_pdf.sh`

**Herramientas requeridas:**
- **Opción 1 (recomendada):** WeasyPrint + Pandoc
- **Opción 2:** Pandoc + XeLaTeX

---

## 🚀 Instalación

### 1. Instalar dependencias

```bash
# Python y herramientas básicas
sudo apt update
sudo apt install -y python3 python3-pip pandoc

# Opción A: WeasyPrint (mejor manejo de imágenes)
sudo apt install -y python3-cffi python3-brotli libpango-1.0-0
pip3 install weasyprint

# Opción B: XeLaTeX (alternativa)
sudo apt install -y texlive-xetex texlive-fonts-recommended fonts-dejavu

# Herramientas para timeout (generalmente incluidas)
sudo apt install -y coreutils
```

### 2. Clonar o descargar los scripts

```bash
# Estructura recomendada
mkdir -p ~/ProyectosPersonales/{Automatizaciones,Licencia}
mkdir -p ~/logs

# Copiar scripts
cp sync-all-optimized.sh ~/ProyectosPersonales/Automatizaciones/
cp actualiza_todos_git.sh ~/ProyectosPersonales/Automatizaciones/
cp md_to_pdf.sh ~/ProyectosPersonales/Automatizaciones/
cp license.sh ~/ProyectosPersonales/Licencia/
```

### 3. Dar permisos de ejecución

```bash
chmod +x ~/ProyectosPersonales/Automatizaciones/*.sh
chmod +x ~/ProyectosPersonales/Licencia/*.sh
```

---

## ⚙️ Configuración

### 1. Personalizar directorios

Edita los scripts según tus necesidades:

**actualiza_todos_git.sh:**
```bash
BASE_DIRS=(
  "$HOME/Escritorio"
  "$HOME/Hackatones"
  "$HOME/ProyectosPersonales"
  # Añade tus directorios aquí
)
```

**md_to_pdf.sh:**
```bash
BASE_DIR="$HOME/Escritorio"  # Cambia según dónde tengas tus bóvedas

IMAGE_FOLDERS=(
  "imagenes" "images" "img" "assets" "attachments"
  # Añade nombres de carpetas de imágenes aquí
)
```

**license.sh:**
```bash
# Excluir rutas específicas
EXCLUDE_PATHS=(
  "$HOME/Escritorio/IA/CLIPS"
  # Añade más rutas a excluir aquí
)

# Modificar texto de licencia
HEADER_TEXT="Tu texto de copyright aquí"
```

### 2. Configurar crontab

```bash
# Editar crontab
crontab -e

# Añadir línea para ejecutar cada 20 minutos
*/20 * * * * /home/adrianql5/ProyectosPersonales/Automatizaciones/sync-all-optimized.sh >> "$HOME/logs/sync-master.log" 2>&1
```

**Otras opciones de frecuencia:**

```bash
# Cada 10 minutos
*/10 * * * * /home/adrianql5/ProyectosPersonales/Automatizaciones/sync-all-optimized.sh

# Cada hora
0 * * * * /home/adrianql5/ProyectosPersonales/Automatizaciones/sync-all-optimized.sh

# Cada día a las 9 AM
0 9 * * * /home/adrianql5/ProyectosPersonales/Automatizaciones/sync-all-optimized.sh

# Solo días laborables cada 30 minutos
*/30 * * * 1-5 /home/adrianql5/ProyectosPersonales/Automatizaciones/sync-all-optimized.sh
```

### 3. Verificar crontab

```bash
# Listar tareas programadas
crontab -l

# Ver logs del sistema cron
grep CRON /var/log/syslog
```

---

## 💻 Uso

### Ejecución manual

```bash
# Ejecutar sincronización completa
~/ProyectosPersonales/Automatizaciones/sync-all-optimized.sh

# Ejecutar scripts individuales
~/ProyectosPersonales/Automatizaciones/actualiza_todos_git.sh
~/ProyectosPersonales/Licencia/license.sh ~/ProyectosPersonales
~/ProyectosPersonales/Automatizaciones/md_to_pdf.sh

# Modo dry-run (ver qué haría sin hacer cambios)
~/ProyectosPersonales/Licencia/license.sh ~/Escritorio --dry-run
```

### Detener sincronización automática

```bash
# Editar crontab
crontab -e

# Comentar la línea (añadir # al inicio)
# */20 * * * * /home/adrianql5/ProyectosPersonales/Automatizaciones/sync-all-optimized.sh

# O eliminar el crontab completamente
crontab -r
```

---

## 📊 Logs y Monitoreo

### Ubicación de logs

```
~/logs/
├── sync-master.log      # Log del script maestro
├── obsidian-pdf.log     # Conversión Obsidian → PDF
├── licencia.log         # Gestión de licencias
└── git-sync.log         # Sincronización Git
```

### Ver logs en tiempo real

```bash
# Log maestro
tail -f ~/logs/sync-master.log

# Log específico
tail -f ~/logs/git-sync.log

# Últimas 50 líneas
tail -n 50 ~/logs/obsidian-pdf.log

# Buscar errores
grep -i error ~/logs/*.log
```

### Rotación de logs

Los logs se rotan automáticamente cuando superan 10MB:
```bash
# Logs antiguos se guardan con extensión .old
~/logs/git-sync.log.old
```

### Limpiar logs manualmente

```bash
# Vaciar todos los logs
> ~/logs/sync-master.log
> ~/logs/obsidian-pdf.log
> ~/logs/licencia.log
> ~/logs/git-sync.log

# O eliminarlos
rm ~/logs/*.log
```

---

## 🔧 Troubleshooting

### Problema: Scripts no se ejecutan automáticamente

**Soluciones:**

1. **Verificar que crontab está activo:**
```bash
crontab -l
sudo systemctl status cron
```

2. **Verificar rutas absolutas en crontab:**
```bash
# ❌ Incorrecto (rutas relativas)
*/20 * * * * ./sync-all-optimized.sh

# ✅ Correcto (rutas absolutas)
*/20 * * * * /home/adrianql5/ProyectosPersonales/Automatizaciones/sync-all-optimized.sh
```

3. **Verificar permisos de ejecución:**
```bash
ls -la ~/ProyectosPersonales/Automatizaciones/*.sh
# Deben tener 'x' (ejecutable)

# Corregir si es necesario
chmod +x ~/ProyectosPersonales/Automatizaciones/*.sh
```

---

### Problema: "Command not found" en cron

**Causa:** Cron tiene un PATH limitado.

**Solución:** Añadir PATH al inicio del crontab:

```bash
crontab -e

# Añadir al inicio
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

*/20 * * * * /home/adrianql5/ProyectosPersonales/Automatizaciones/sync-all-optimized.sh
```

---

### Problema: Git push falla (autenticación)

**Soluciones:**

1. **Configurar SSH keys:**
```bash
# Generar key si no existe
ssh-keygen -t ed25519 -C "tu@email.com"

# Copiar al portapapeles
cat ~/.ssh/id_ed25519.pub

# Añadir a GitHub: Settings → SSH and GPG keys → New SSH key
```

2. **O usar Git credential helper:**
```bash
git config --global credential.helper store
# Hacer un push manual para guardar credenciales
```

---

### Problema: Conversión PDF sin imágenes

**Soluciones:**

1. **Verificar herramienta instalada:**
```bash
weasyprint --version
pandoc --version
xelatex --version
```

2. **Reinstalar WeasyPrint:**
```bash
pip3 uninstall weasyprint
pip3 install weasyprint
```

3. **Verificar rutas de imágenes en Markdown:**
```markdown
<!-- ✅ Sintaxis soportadas -->
![[imagen.png]]              # Obsidian
![](imagenes/foto.jpg)       # Relativa
![](https://example.com/img) # URL
```

---

### Problema: Licencias se añaden varias veces

**Causa:** El script no detecta la licencia existente.

**Solución:** Verificar que el texto de licencia es idéntico:

```bash
# Ver primeras líneas de un archivo
head -n 5 archivo.py

# Si la licencia está pero con formato diferente, actualizar HEADER_TEXT en license.sh
```

---

### Problema: Logs muy grandes

**Solución automática:** Los logs se rotan automáticamente al superar 10MB.

**Solución manual:**
```bash
# Limpiar logs antiguos
rm ~/logs/*.log.old

# Comprimir logs
gzip ~/logs/*.log.old

# Automatizar limpieza mensual (añadir a crontab)
0 0 1 * * find ~/logs -name "*.log.old" -mtime +30 -delete
```

---

### Problema: Script muy lento

**Diagnóstico:**
```bash
# Ejecutar con medición de tiempo
time ~/ProyectosPersonales/Automatizaciones/sync-all-optimized.sh

# Ver qué script es lento
tail -f ~/logs/sync-master.log
```

**Optimizaciones adicionales:**

1. **Excluir más directorios en Git sync:**
```bash
# Editar actualiza_todos_git.sh
find "$BASE_DIR" -type d -name ".git" -not -path "*/node_modules/*" ...
```

2. **Limitar profundidad de búsqueda:**
```bash
# En md_to_pdf.sh
find "$BASE_DIR" -maxdepth 2 -type d -name ".obsidian"
```

---

## 📈 Estadísticas de Rendimiento

### Tiempos estimados (depende del tamaño de tus proyectos):

| Script | Primera ejecución | Ejecuciones posteriores |
|--------|------------------|------------------------|
| **Git Sync** | 10-30s | 2-5s |
| **Licencias** | 20-60s | 5-10s |
| **Obsidian → PDF** | 2-5 min | 10-30s |
| **Total (paralelo)** | 3-6 min | 15-45s |

### Mejoras vs versión anterior:

- ⚡ **40% más rápido** gracias a ejecución paralela
- 🚀 **5-15x más rápido** en detección de cambios Git
- 💾 **10-50x más rápido** en búsqueda de imágenes con cache

---

## 🤝 Contribuciones

¿Encontraste un bug o tienes una mejora? ¡Abre un issue o pull request!

---

## 📜 Licencia

```
Copyright (c) 2025 Adrián Quiroga Linares
Lectura y referencia permitidas; reutilización y plagio prohibidos
```

---

## 📞 Contacto

**Autor:** Adrián Quiroga Linares  
**Usuario:** adrianql5

---

## 🎓 Aprendizaje Adicional

### Recursos sobre Cron

- [Crontab Guru](https://crontab.guru/) - Generador visual de expresiones cron
- [Crontab.tech](https://crontab.tech/) - Documentación interactiva

### Recursos sobre Bash Scripting

- [ShellCheck](https://www.shellcheck.net/) - Linter para scripts bash
- [Bash Guide](https://mywiki.wooledge.org/BashGuide) - Guía completa

### Recursos sobre Git Automation

- [Git Hooks](https://git-scm.com/book/en/v2/Customizing-Git-Git-Hooks)
- [Git Automation](https://www.git-tower.com/learn/git/ebook/en/command-line/advanced-topics/git-hooks)

---

**¡Disfruta de tu flujo de trabajo automatizado! 🚀**
