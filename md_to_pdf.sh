#!/bin/bash
# Copyright (c) 2025 Adrián Quiroga Linares Lectura y referencia permitidas; reutilización y plagio prohibidos

set -euo pipefail

BASE_DIR="$HOME/Escritorio"

IMAGE_FOLDERS=(
  "imagenes" "images" "img" "assets" "attachments" "adjuntos"
  "recursos" "resources" "media" "fotos" "photos" "Pasted image"
)

# Script Python optimizado (cache de búsqueda de imágenes)
PYTHON_PROCESSOR=$(
  cat <<'PYTHON_END'
import sys
import os
import re
from pathlib import Path
from functools import lru_cache

@lru_cache(maxsize=1000)
def find_image_cached(vault_path, img_name):
    """Búsqueda con cache para evitar búsquedas repetidas"""
    vault = Path(vault_path)
    for img_path in vault.rglob(img_name):
        if img_path.is_file():
            return str(img_path.absolute())
    return None

def process_markdown(md_file, vault_path, output_file):
    vault_path = Path(vault_path)
    md_file = Path(md_file)
    md_dir = md_file.parent
    
    with open(md_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Procesar sintaxis Obsidian: ![[imagen.png]]
    def replace_obsidian_images(match):
        img_name = match.group(1)
        img_path = find_image_cached(str(vault_path), img_name)
        if img_path:
            return f'![{img_name}]({img_path})'
        return match.group(0)
    
    content = re.sub(r'!\[\[([^\]]+)\]\]', replace_obsidian_images, content)
    
    # Procesar sintaxis Markdown: ![alt](ruta)
    def replace_markdown_images(match):
        alt_text = match.group(1)
        img_rel_path = match.group(2)
        
        if img_rel_path.startswith('/') or img_rel_path.startswith('http'):
            return match.group(0)
        
        img_abs = md_dir / img_rel_path
        if img_abs.exists():
            return f'![{alt_text}]({img_abs.absolute()})'
        
        img_name = os.path.basename(img_rel_path)
        img_path = find_image_cached(str(vault_path), img_name)
        if img_path:
            return f'![{alt_text}]({img_path})'
        
        return match.group(0)
    
    content = re.sub(r'!\[([^\]]*)\]\(([^)]+)\)', replace_markdown_images, content)
    
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(content)

if __name__ == '__main__':
    if len(sys.argv) != 4:
        sys.exit(1)
    process_markdown(sys.argv[1], sys.argv[2], sys.argv[3])
PYTHON_END
)

PYTHON_SCRIPT=$(mktemp --suffix=.py)
echo "$PYTHON_PROCESSOR" >"$PYTHON_SCRIPT"
trap "rm -f $PYTHON_SCRIPT" EXIT

convert_md_to_pdf() {
  local md_file="$1"
  local pdf_file="$2"
  local vault_path="$3"
  local temp_md temp_html

  temp_md=$(mktemp --suffix=.md)

  python3 "$PYTHON_SCRIPT" "$md_file" "$vault_path" "$temp_md" || {
    rm -f "$temp_md"
    return 1
  }

  if [[ "$CONVERTER" == "weasyprint" ]]; then
    temp_html=$(mktemp --suffix=.html)
    pandoc "$temp_md" -o "$temp_html" --standalone --self-contained --embed-resources --resource-path="$vault_path" 2>/dev/null
    sed -i 's|</head>|<style>body{font-family:Arial,sans-serif;max-width:800px;margin:40px auto;line-height:1.6}img{max-width:100%;height:auto;display:block;margin:20px 0}</style></head>|' "$temp_html"
    weasyprint "$temp_html" "$pdf_file" 2>/dev/null
    local result=$?
    rm -f "$temp_html" "$temp_md"
  else
    pandoc "$temp_md" -o "$pdf_file" --pdf-engine=xelatex --variable=geometry:margin=2.5cm --variable=fontsize=11pt --variable=mainfont="DejaVu Sans" --highlight-style=tango --standalone --resource-path="$vault_path" 2>/dev/null
    local result=$?
    rm -f "$temp_md"
  fi

  return $result
}

detect_converter() {
  command -v python3 &>/dev/null || {
    echo "none"
    return
  }
  if command -v weasyprint &>/dev/null && command -v pandoc &>/dev/null; then
    echo "weasyprint"
  elif command -v pandoc &>/dev/null && command -v xelatex &>/dev/null; then
    echo "pandoc"
  else
    echo "none"
  fi
}

is_image_folder() {
  local base_name=$(basename "$1")
  for img_folder in "${IMAGE_FOLDERS[@]}"; do
    [[ "$base_name" == "$img_folder" || "$base_name" =~ ^${img_folder} ]] && return 0
  done
  return 1
}

process_vault() {
  local vault_path="$1"
  local vault_name=$(basename "$vault_path")
  local pdf_vault_path="$(dirname "$vault_path")/${vault_name}_PDF"

  echo "Procesando: $vault_name"

  local is_first_run=false
  [[ ! -d "$pdf_vault_path" ]] && {
    mkdir -p "$pdf_vault_path"
    is_first_run=true
  }

  if $is_first_run; then
    echo "  Primera ejecución: copiando estructura..."

    # Copiar directorios (optimizado)
    find "$vault_path" -type d -not -path "*/.obsidian*" -not -path "*/.git*" -print0 |
      while IFS= read -r -d '' dir; do
        local rel_path="${dir#$vault_path/}"
        [[ "$rel_path" != "$vault_path" ]] && ! is_image_folder "$dir" && mkdir -p "$pdf_vault_path/$rel_path"
      done

    # Copiar archivos no-MD (optimizado con find paralelo)
    local copied=0
    find "$vault_path" -type f -not -name "*.md" -not -path "*/.obsidian*" -print0 |
      while IFS= read -r -d '' file; do
        local rel_path="${file#$vault_path/}"
        local skip=false
        for img_folder in "${IMAGE_FOLDERS[@]}"; do
          [[ "$rel_path" =~ /$img_folder/ || "$rel_path" =~ ^$img_folder/ ]] && {
            skip=true
            break
          }
        done
        $skip && continue
        local dest="$pdf_vault_path/$rel_path"
        mkdir -p "$(dirname "$dest")"
        cp -p "$file" "$dest" 2>/dev/null && ((copied++))
      done
    echo "  ✓ Archivos copiados: $copied"
  fi

  # Procesar .md (optimizado con array)
  local md_files=()
  while IFS= read -r -d '' file; do
    md_files+=("$file")
  done < <(find "$vault_path" -type f -name "*.md" -not -path "*/.obsidian*" -not -path "*/.git*" -print0)

  local total=${#md_files[@]}
  local updated=0 skipped=0 failed=0 new=0

  echo "  Archivos .md: $total"

  for ((i = 0; i < $total; i++)); do
    local md_file="${md_files[$i]}"
    local rel_path="${md_file#$vault_path/}"
    local pdf_file="$pdf_vault_path/${rel_path%.md}.pdf"

    # Verificar si necesita actualización (optimizado)
    if [[ -f "$pdf_file" && ! "$md_file" -nt "$pdf_file" ]]; then
      ((skipped++))
      continue
    fi

    mkdir -p "$(dirname "$pdf_file")"
    [[ ! -f "$pdf_file" ]] && ((new++))
    [[ -f "$pdf_file" ]] && rm -f "$pdf_file"

    if convert_md_to_pdf "$md_file" "$pdf_file" "$vault_path" && [[ -s "$pdf_file" ]]; then
      ((updated++))
    else
      ((failed++))
      rm -f "$pdf_file" 2>/dev/null
    fi
  done

  # Limpiar PDFs huérfanos (optimizado)
  local orphaned=0
  find "$pdf_vault_path" -type f -name "*.pdf" -print0 |
    while IFS= read -r -d '' pdf_file; do
      local rel_path="${pdf_file#$pdf_vault_path/}"
      local md="$vault_path/${rel_path%.pdf}.md"
      local orig_pdf="$vault_path/$rel_path"
      [[ ! -f "$md" && ! -f "$orig_pdf" ]] && {
        rm -f "$pdf_file"
        ((orphaned++))
      }
    done

  echo "  ✓ Nuevos:$new Actualizados:$updated Saltados:$skipped Huérfanos:$orphaned Fallos:$failed"
}

# Verificar dependencias
command -v python3 &>/dev/null || {
  echo "ERROR: Python3 no instalado"
  exit 1
}

CONVERTER=$(detect_converter)
[[ "$CONVERTER" == "none" ]] && {
  echo "ERROR: Instala pandoc + weasyprint o pandoc + texlive-xetex"
  exit 1
}

[[ ! -d "$BASE_DIR" ]] && {
  echo "ERROR: $BASE_DIR no existe"
  exit 1
}

echo "=== Sincronizador Obsidian → PDF ($CONVERTER) ==="

# Procesar bóvedas (optimizado con array)
vaults=()
while IFS= read -r -d '' obsidian_dir; do
  vaults+=("$(dirname "$obsidian_dir")")
done < <(find "$BASE_DIR" -maxdepth 3 -type d -name ".obsidian" -print0 2>/dev/null)

for vault in "${vaults[@]}"; do
  process_vault "$vault"
done

echo "=== Completado: $(date '+%H:%M:%S') ==="
