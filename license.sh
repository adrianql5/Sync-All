#!/usr/bin/env bash
# Copyright (c) 2025 Adrián Quiroga Linares Lectura y referencia permitidas; reutilización y plagio prohibidos

set -euo pipefail
IFS=$'\n\t'

usage() {
  echo "Uso: $0 <directorio> [--dry-run] [--raw]"
  echo "  --dry-run  Muestra qué archivos se modificarían sin escribir cambios"
  echo "  --raw      Inserta el texto sin comentar (fuerza texto en crudo en todos los tipos)"
  exit 1
}

if [[ $# -lt 1 ]]; then
  usage
fi

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

if [[ ! -d "$ROOT" ]]; then
  echo "Error: '$ROOT' no es un directorio."
  exit 1
fi

HEADER_TEXT="Copyright (c) 2025 Adrián Quiroga Linares Lectura y referencia permitidas; reutilización y plagio prohibidos"

# Extensiones permitidas (solo estas se procesan)
ALLOW_EXTS=(py md txt java c h clp sql cpp sh)

# Directorios específicos a excluir
EXCLUDE_DIRS=(
  .git node_modules vendor dist build target out .venv venv __pycache__ .idea .vscode
  coverage .next .nuxt .cache .gradle .pytest_cache .tox .mypy_cache .terraform .pio
)

# Rutas absolutas específicas a excluir
EXCLUDE_PATHS=(
  "$HOME/Escritorio/IA/CLIPS"
)

# Detección de archivo de texto (no binario)
is_text_file() {
  local f="$1"
  LC_ALL=C grep -Iq . "$f" 2>/dev/null
}

# Comprobar si el archivo ya contiene el HEADER_TEXT en las primeras líneas
has_header_already() {
  local f="$1"
  head -n 15 "$f" 2>/dev/null | grep -Fq "$HEADER_TEXT"
}

# Comprobar si el archivo está en una ruta excluida
is_in_excluded_path() {
  local f="$1"
  local abs_file
  abs_file="$(realpath "$f" 2>/dev/null || echo "$f")"

  for excluded_path in "${EXCLUDE_PATHS[@]}"; do
    local abs_excluded
    abs_excluded="$(realpath "$excluded_path" 2>/dev/null || echo "$excluded_path")"

    # Verificar si el archivo está dentro del directorio excluido
    if [[ "$abs_file" == "$abs_excluded"* ]]; then
      return 0
    fi
  done
  return 1
}

# ¿Debemos procesar esta extensión?
is_allowed_ext() {
  local f="$1"
  local ext="${f##*.}"
  ext="$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')"
  # Sin extensión => no permitido
  [[ "$ext" == "$f" ]] && return 1
  for a in "${ALLOW_EXTS[@]}"; do
    if [[ "$ext" == "$a" ]]; then
      return 0
    fi
  done
  return 1
}

# Estilo de comentario según extensión
# Devuelve globales: STYLE ("line"|"block"|"raw"), PREFIX, SUFFIX
get_comment_style() {
  local f="$1"
  local ext="${f##*.}"
  ext="$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')"

  STYLE="line"
  PREFIX="# "
  SUFFIX=""

  case "$ext" in
  py | sh)
    STYLE="line"
    PREFIX="# "
    SUFFIX=""
    ;;
  java | c | cpp | h)
    STYLE="line"
    PREFIX="// "
    SUFFIX=""
    ;;
  sql)
    STYLE="line"
    PREFIX="-- "
    SUFFIX=""
    ;;
  clp)
    STYLE="line"
    PREFIX="; "
    SUFFIX=""
    ;;
  md)
    STYLE="block"
    PREFIX="<!-- "
    SUFFIX=" -->"
    ;;
  txt)
    STYLE="raw"
    PREFIX=""
    SUFFIX=""
    ;;
  *)
    # Por si acaso, usar comentario de línea por defecto
    STYLE="line"
    PREFIX="# "
    SUFFIX=""
    ;;
  esac
}

process_file() {
  local f="$1"

  # Verificar si está en una ruta excluida
  if is_in_excluded_path "$f"; then
    if $DRY_RUN; then
      echo "[dry-run] Saltando (ruta excluida): $f"
    fi
    return
  fi

  local base
  base="$(basename "$f")"

  # Ignorar README.md (insensible a mayúsculas/minúsculas)
  local base_lc
  base_lc="$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]')"
  if [[ "$base_lc" == "readme.md" ]]; then
    return
  fi

  # Solo trabajar con extensiones permitidas
  if ! is_allowed_ext "$f"; then
    return
  fi

  # Solo archivos de texto
  if ! is_text_file "$f"; then
    return
  fi

  # Evitar duplicar cabecera
  if has_header_already "$f"; then
    return
  fi

  local header_block
  if $RAW; then
    header_block="${HEADER_TEXT}\n\n"
  else
    get_comment_style "$f"
    case "$STYLE" in
    block) header_block="${PREFIX}${HEADER_TEXT}${SUFFIX}\n\n" ;;
    line) header_block="${PREFIX}${HEADER_TEXT}\n\n" ;;
    raw) header_block="${HEADER_TEXT}\n\n" ;;
    esac
  fi

  if $DRY_RUN; then
    echo "[dry-run] Añadiría cabecera a: $f"
    return
  fi

  local tmp
  tmp="$(mktemp)"

  local first_line
  first_line="$(head -n 1 "$f" 2>/dev/null || true)"

  if [[ "$first_line" =~ ^#! ]]; then
    printf '%s\n' "$first_line" >"$tmp"
    printf '%b' "$header_block" >>"$tmp"
    tail -n +2 "$f" >>"$tmp"
  else
    printf '%b' "$header_block" >"$tmp"
    cat "$f" >>"$tmp"
  fi

  # Preservar permisos
  local mode=""
  if mode="$(stat -c '%a' "$f" 2>/dev/null)"; then
    chmod "$mode" "$tmp" 2>/dev/null || true
  elif mode="$(stat -f '%Lp' "$f" 2>/dev/null)"; then
    chmod "$mode" "$tmp" 2>/dev/null || true
  fi

  mv "$tmp" "$f"
  echo "Añadida cabecera a: $f"
}

# Construir cláusulas -path para find
PRUNE_EXPR=()
for d in "${EXCLUDE_DIRS[@]}"; do
  if [[ -n "${PRUNE_EXPR[*]:-}" ]]; then
    PRUNE_EXPR+=(-o)
  fi
  PRUNE_EXPR+=(-path "*/${d}" -o -path "*/${d}/*")
done

# Ejecutar find excluyendo directorios específicos
if [[ ${#PRUNE_EXPR[@]} -gt 0 ]]; then
  while IFS= read -r -d '' file; do
    process_file "$file"
  done < <(find "$ROOT" -type f \! \( "${PRUNE_EXPR[@]}" \) -print0)
else
  while IFS= read -r -d '' file; do
    process_file "$file"
  done < <(find "$ROOT" -type f -print0)
fi

echo "Proceso completado."
