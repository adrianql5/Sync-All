#!/usr/bin/env bash
# Copyright (c) 2025 Adrián Quiroga Linares Lectura y referencia permitidas; reutilización y plagio prohibidos

set -euo pipefail
IFS=$'\n\t'

usage() {
  echo "Uso: $0 <directorio> [--dry-run] [--all] [--backup]"
  echo "  --dry-run  Muestra qué archivos se modificarían sin escribir cambios"
  echo "  --all      Ignora el filtro por extensiones (intenta revertir en todos los archivos de texto)"
  echo "  --backup   Crea una copia .bak antes de modificar cada archivo"
  exit 1
}

if [[ $# -lt 1 ]]; then
  usage
fi

ROOT="$1"
shift || true
DRY_RUN=false
ALL=false
BACKUP=false
while [[ $# -gt 0 ]]; do
  case "$1" in
  --dry-run) DRY_RUN=true ;;
  --all) ALL=true ;;
  --backup) BACKUP=true ;;
  -h | --help) usage ;;
  *)
    echo "Opción no reconocida: $1"
    usage
    ;;
  esac
  shift || true
done

if [[ ! -d "$ROOT" ]]; then
  echo "Error: '$ROOT' no es un directorio."
  exit 1
fi

HEADER_TEXT="Copyright (c) 2025 Adrián Quiroga Linares Lectura y referencia permitidas; reutilización y plagio prohibidos"

# Directorios a excluir
EXCLUDE_DIRS=(
  .git node_modules vendor dist build target out .venv venv __pycache__ .idea .vscode
  coverage .next .nuxt .cache .gradle .pytest_cache .tox .mypy_cache .terraform .pio
)

# Basenames de archivos a excluir (lockfiles y otros sensibles)
EXCLUDE_BASENAMES=(
  yarn.lock pnpm-lock.yaml package-lock.json Pipfile.lock poetry.lock Cargo.lock
  Gemfile.lock composer.lock Podfile.lock go.sum
)

# Extensiones que NO deben tocarse por defecto
SKIP_EXTS=(
  json csv tsv ndjson parquet avro
  exe dll so dylib bin class jar war ear wasm
  pdf zip gz tar tgz bz2 7z rar
  png jpg jpeg gif webp ico bmp psd svgz
  # minificados
  min.js min.css
  # evitar PHP por la apertura obligatoria
  php
)

# Detección de archivo de texto (no binario)
is_text_file() {
  local f="$1"
  LC_ALL=C grep -Iq . "$f"
}

# Saltar por basename
should_skip_basename() {
  local base="$1"
  for b in "${EXCLUDE_BASENAMES[@]}"; do
    if [[ "$base" == "$b" ]]; then return 0; fi
  done
  return 1
}

# Saltar por extensión (0 = saltar, 1 = no saltar)
should_skip_ext() {
  local f="$1"
  local base ext
  base="$(basename "$f")"
  ext="${f##*.}"
  ext="$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')"

  # minificados exactos
  if [[ "$f" == *.min.js || "$f" == *.min.css ]]; then return 0; fi

  for e in "${SKIP_EXTS[@]}"; do
    if [[ "$ext" == "$e" ]]; then return 0; fi
  done
  return 1
}

process_file() {
  local f="$1"

  local base
  base="$(basename "$f")"
  if should_skip_basename "$base"; then
    return
  fi

  if ! $ALL; then
    if ! should_skip_ext "$f"; then
      return
    fi
  fi

  if ! is_text_file "$f"; then
    return
  fi

  # Prepara archivo temporal
  local tmp
  tmp="$(mktemp)"

  # AWK que elimina la cabecera insertada por el script anterior.
  # Maneja: shebang en primera línea, comentario de línea (#, //, --, %),
  # comentario de bloque en una sola línea (/* ... */ y <!-- ... -->) y versión raw.
  awk -v header="$HEADER_TEXT" '
    function trim(s) {
      sub(/^[ \t\r\n]+/, "", s); sub(/[ \t\r\n]+$/, "", s); return s
    }
    function is_header_line(s,   t) {
      t = trim(s)
      return (t == "# " header) \
          || (t == "// " header) \
          || (t == "-- " header) \
          || (t == "% " header) \
          || (t == "/* " header " */") \
          || (t == "<!-- " header " -->") \
          || (t == header)
    }
    BEGIN { state="start"; after_header=0 }
    NR==1 {
      if ($0 ~ /^#!/) { print $0; state="post_shebang"; next }
      if (is_header_line($0)) { state="after_header"; after_header=1; next }
      print $0; state="normal"; next
    }
    state=="post_shebang" && NR==2 {
      if (is_header_line($0)) { state="after_header"; after_header=1; next }
      print $0; state="normal"; next
    }
    state=="after_header" {
      # Saltar solo UNA línea en blanco añadida por el script (si existe)
      if ($0 ~ /^[ \t\r]*$/) { state="normal"; next }
      # Si no es en blanco, continuar normal
      print $0; state="normal"; next
    }
    { print $0 }
  ' "$f" >"$tmp"

  # Si no hay cambios, descartar tmp
  if cmp -s "$f" "$tmp"; then
    rm -f "$tmp"
    return
  fi

  if $DRY_RUN; then
    echo "[dry-run] Revertiría cabecera en: $f"
    rm -f "$tmp"
    return
  fi

  # Backup opcional
  if $BACKUP; then
    cp -p "$f" "$f.bak" 2>/dev/null || cp "$f" "$f.bak"
  fi

  # Preservar permisos al mover
  local mode=""
  if mode="$(stat -c '%a' "$f" 2>/dev/null)"; then
    chmod "$mode" "$tmp" 2>/dev/null || true
  elif mode="$(stat -f '%Lp' "$f" 2>/dev/null)"; then
    chmod "$mode" "$tmp" 2>/dev/null || true
  fi

  mv "$tmp" "$f"
  echo "Revertida cabecera en: $f"
}

export -f process_file is_text_file should_skip_basename should_skip_ext
export HEADER_TEXT DRY_RUN ALL BACKUP

# Construir cláusulas -prune para find sin eval
PRUNE_CLAUSES=()
for d in "${EXCLUDE_DIRS[@]}"; do
  PRUNE_CLAUSES+=(-name "$d" -o)
done
if ((${#PRUNE_CLAUSES[@]} > 0)); then
  unset 'PRUNE_CLAUSES[${#PRUNE_CLAUSES[@]}-1]'
fi

if ((${#PRUNE_CLAUSES[@]} > 0)); then
  find "$ROOT" -type d "(" "${PRUNE_CLAUSES[@]}" ")" -prune -o -type f -print0 |
    while IFS= read -r -d '' file; do
      process_file "$file"
    done
else
  find "$ROOT" -type f -print0 |
    while IFS= read -r -d '' file; do
      process_file "$file"
    done
fi
