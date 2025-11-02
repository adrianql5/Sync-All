#!/bin/bash
# Copyright (c) 2025 Adrián Quiroga Linares Lectura y referencia permitidas; reutilización y plagio prohibidos

set -euo pipefail

LOG_DIR="$HOME/logs"
SCRIPTS_DIR="$HOME/ProyectosPersonales/Automatizaciones"
LICENSE_SCRIPT="$HOME/ProyectosPersonales/Licencia/license.sh"

# Crear logs si no existen
mkdir -p "$LOG_DIR"

# Función para logging con timestamp
log() {
  echo "[$(date '+%H:%M:%S')] $*"
}

log_section() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "$1"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Función para ejecutar con timeout y logging
run_with_timeout() {
  local timeout_sec=$1
  local log_file=$2
  shift 2
  local cmd=("$@")

  if timeout "${timeout_sec}s" "${cmd[@]}" >>"$log_file" 2>&1; then
    return 0
  else
    local exit_code=$?
    [[ $exit_code -eq 124 ]] && log "⚠ Timeout después de ${timeout_sec}s" || log "✗ Error: código $exit_code"
    return $exit_code
  fi
}

# Verificar scripts existen
for script in "$SCRIPTS_DIR/md_to_pdf.sh" "$LICENSE_SCRIPT" "$SCRIPTS_DIR/actualiza_todos_git.sh"; do
  [[ ! -x "$script" ]] && {
    log "✗ Script no encontrado o no ejecutable: $script"
    exit 1
  }
done

# Inicio
START_TIME=$(date +%s)
log_section "Sincronización Automática [PID: $$]"

# 1. Obsidian → PDF (con timeout de 10 minutos)
log "[1/3] Sincronizando Obsidian → PDF..."
if run_with_timeout 600 "$LOG_DIR/obsidian-pdf.log" "$SCRIPTS_DIR/md_to_pdf.sh"; then
  log "  ✓ Obsidian sincronizado"
else
  log "  ⚠ Obsidian con problemas (ver log)"
fi

# 2. Añadir licencias en paralelo (con timeout de 5 minutos cada uno)
log "[2/3] Añadiendo licencias..."
{
  run_with_timeout 300 "$LOG_DIR/licencia.log" "$LICENSE_SCRIPT" "$HOME/ProyectosPersonales" &
  PID1=$!
  run_with_timeout 300 "$LOG_DIR/licencia.log" "$LICENSE_SCRIPT" "$HOME/Escritorio" &
  PID2=$!

  # Esperar ambos procesos
  wait $PID1 && log "  ✓ Licencias ProyectosPersonales" || log "  ⚠ Error en ProyectosPersonales"
  wait $PID2 && log "  ✓ Licencias Escritorio" || log "  ⚠ Error en Escritorio"
}

# 3. Git sync (con timeout de 10 minutos)
log "[3/3] Actualizando Git..."
if run_with_timeout 600 "$LOG_DIR/git-sync.log" "$SCRIPTS_DIR/actualiza_todos_git.sh"; then
  log "  ✓ Git actualizado"
else
  log "  ⚠ Git con problemas (ver log)"
fi

# Resumen final
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
log_section "Completado en ${DURATION}s [$(date '+%H:%M:%S')]"

# Rotar logs si son muy grandes (>10MB)
for logfile in "$LOG_DIR"/*.log; do
  [[ -f "$logfile" && $(stat -f%z "$logfile" 2>/dev/null || stat -c%s "$logfile" 2>/dev/null) -gt 10485760 ]] && {
    mv "$logfile" "${logfile}.old"
    log "  ↻ Log rotado: $(basename "$logfile")"
  }
done
