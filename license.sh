#!/usr/bin/env bash
# Copyright (c) 2025 Adrián Quiroga Linares Lectura y referencia permitidas; reutilización y plagio prohibidos

set -euo pipefail

usage() {
  echo "Uso: $0 <directorio> [--dry-run] [--raw]"
  echo "  --dry-run  Muestra qué archivos se modificarían sin escribir cambios"
  echo "  --raw      Inserta el texto sin comentar (fuerza texto en crudo)"
  exit 1
}

[[ $# -lt 1 ]] && usage

ROOT="$1"
shift
DRY_RUN=false
RAW=false

while [[ $# -gt 0 ]]; do
  case "$1" in
  --dry-run) DRY_RUN=true ;;
  --raw) RAW=true ;;
  -h | --help) usage ;;
  *)
    echo "Opción no reconocida: $1"
    usage
    ;;
  esac
  shift
done

[[ ! -d "$ROOT" ]] && {
  echo "Error: '$ROOT' no es un directorio."
  exit 1
}

HEADER_TEXT="Copyright (c) 2025 Adrián Quiroga Linares Lectura y referencia permitidas; reutilización y plagio prohibidos"

# Extensiones permitidas (lookup rápido)
declare -A ALLOW_EXTS_MAP=(
  [py]=1 [md]=1 [txt]=1 [java]=1 [c]=1 [h]=1
  [clp]=1 [sql]=1 [cpp]=1 [sh]=1
)

EXCLUDE_DIRS=(
  .git node_modules vendor dist build target out .venv venv __pycache__
  .idea .vscode coverage .next .nuxt .cache .gradle .pytest_cache .tox
  .mypy_cache .terraform .pio
)

EXCLUDE_PATHS=(
  "$HOME/Escritorio/IA/CLIPS"
)

# Cache de rutas excluidas normalizadas
declare -A EXCLUDED_PATHS_CACHE
for path in "${EXCLUDE_PATHS[@]}"; do
  real_path=$(realpath "$path" 2>/dev/null || echo "$path")
  EXCLUDED_PATHS_CACHE["$real_path"]=1
done

# Verificaciones optimizadas
is_text_file() {
  file -b --mime-encoding "$1" 2>/dev/null | grep -qE "^(us-ascii|utf-8|iso-8859)"
}

has_header_already() {
  head -n 3 "$1" 2>/dev/null | grep -Fq "$HEADER_TEXT"
}

is_in_excluded_path() {
  local abs_file=$(realpath "$1" 2>/dev/null || echo "$1")
  for excluded in "${!EXCLUDED_PATHS_CACHE[@]}"; do
    [[ "$abs_file" == "$excluded"* ]] && return 0
  done
  return 1
}

is_allowed_ext() {
  local ext="${1##*.}"
  ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
  [[ "$ext" == "$1" ]] && return 1
  [[ ${ALLOW_EXTS_MAP[$ext]+_} ]]
}

get_comment_style() {
  local ext="${1##*.}"
  ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')

  case "$ext" in
  py | sh)
    PREFIX="# "
    SUFFIX=""
    ;;
  java | c | cpp | h)
    PREFIX="// "
    SUFFIX=""
    ;;
  sql)
    PREFIX="-- "
    SUFFIX=""
    ;;
  clp)
    PREFIX="; "
    SUFFIX=""
    ;;
  md)
    PREFIX="<!-- "
    SUFFIX=" -->"
    ;;
  txt)
    PREFIX=""
    SUFFIX=""
    ;;
  *)
    PREFIX="# "
    SUFFIX=""
    ;;
  esac
}

process_file() {
  local f="$1"

  # Verificaciones rápidas primero
  is_in_excluded_path "$f" && return

  local base=$(basename "$f")
  local base_lc=$(echo "$base" | tr '[:upper:]' '[:lower:]')
  [[ "$base_lc" == "readme.md" ]] && return

  is_allowed_ext "$f" || return
  is_text_file "$f" || return
  has_header_already "$f" && return

  # Construir header
  local header_block
  if $RAW; then
    header_block="${HEADER_TEXT}\n\n"
  else
    get_comment_style "$f"
    [[ -n "$SUFFIX" ]] && header_block="${PREFIX}${HEADER_TEXT}${SUFFIX}\n\n" || header_block="${PREFIX}${HEADER_TEXT}\n\n"
  fi

  if $DRY_RUN; then
    echo "[dry-run] Añadiría cabecera a: $f"
    return
  fi

  # Crear archivo temporal
  local tmp=$(mktemp)
  trap "rm -f $tmp" RETURN

  local first_line=$(head -n 1 "$f" 2>/dev/null || true)

  if [[ "$first_line" =~ ^#! ]]; then
    echo "$first_line" >"$tmp"
    printf '%b' "$header_block" >>"$tmp"
    tail -n +2 "$f" >>"$tmp"
  else
    printf '%b' "$header_block" >"$tmp"
    cat "$f" >>"$tmp"
  fi

  # Preservar permisos (optimizado)
  chmod --reference="$f" "$tmp" 2>/dev/null || chmod $(stat -c '%a' "$f" 2>/dev/null || stat -f '%Lp' "$f" 2>/dev/null) "$tmp" 2>/dev/null

  mv "$tmp" "$f"
  echo "✓ $f"
}

# Construir expresión de exclusión optimizada
PRUNE_EXPR=()
for d in "${EXCLUDE_DIRS[@]}"; do
  [[ ${#PRUNE_EXPR[@]} -gt 0 ]] && PRUNE_EXPR+=(-o)
  PRUNE_EXPR+=(-path "*/${d}")
done

# Procesar archivos (optimizado con contador)
echo "Procesando archivos en: $ROOT"
processed=0
added=0

if [[ ${#PRUNE_EXPR[@]} -gt 0 ]]; then
  while IFS= read -r -d '' file; do
    ((processed++))
    if process_file "$file"; then
      ((added++))
    fi
  done < <(find "$ROOT" -type f \( "${PRUNE_EXPR[@]}" \) -prune -o -type f -print0)
else
  while IFS= read -r -d '' file; do
    ((processed++))
    if process_file "$file"; then
      ((added++))
    fi
  done < <(find "$ROOT" -type f -print0)
fi

echo ""
echo "Proceso completado."
echo "  Archivos procesados: $processed"
echo "  Licencias añadidas: $added"
