#!/bin/bash
# Copyright (c) 2025 Adrián Quiroga Linares Lectura y referencia permitidas; reutilización y plagio prohibidos

# Ruta base donde buscar bóvedas de Obsidian
BASE_DIR="$HOME/Escritorio"

# Nombres de carpetas de imágenes a excluir (personaliza según tu estructura)
IMAGE_FOLDERS=(
  "imagenes"
  "images"
  "img"
  "assets"
  "attachments"
  "adjuntos"
  "recursos"
  "resources"
  "media"
  "fotos"
  "photos"
  "Pasted image"
)

# Script Python para procesar imágenes en Markdown
PYTHON_PROCESSOR=$(
  cat <<'PYTHON_END'
import sys
import os
import re
from pathlib import Path

def process_markdown(md_file, vault_path, output_file):
    vault_path = Path(vault_path)
    md_file = Path(md_file)
    md_dir = md_file.parent
    
    with open(md_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Procesar sintaxis de Obsidian: ![[imagen.png]]
    def replace_obsidian_images(match):
        img_name = match.group(1)
        # Buscar la imagen en toda la bóveda
        for img_path in vault_path.rglob(img_name):
            if img_path.is_file():
                return f'![{img_name}]({img_path.absolute()})'
        return match.group(0)  # Si no se encuentra, dejar como está
    
    content = re.sub(r'!\[\[([^\]]+)\]\]', replace_obsidian_images, content)
    
    # Procesar sintaxis Markdown estándar: ![alt](ruta)
    def replace_markdown_images(match):
        alt_text = match.group(1)
        img_rel_path = match.group(2)
        
        # Si ya es absoluta o es URL, dejarla como está
        if img_rel_path.startswith('/') or img_rel_path.startswith('http'):
            return match.group(0)
        
        # Buscar imagen relativa al archivo MD
        img_abs = md_dir / img_rel_path
        if img_abs.exists():
            return f'![{alt_text}]({img_abs.absolute()})'
        
        # Buscar en toda la bóveda por nombre
        img_name = os.path.basename(img_rel_path)
        for img_path in vault_path.rglob(img_name):
            if img_path.is_file():
                return f'![{alt_text}]({img_path.absolute()})'
        
        return match.group(0)  # Si no se encuentra, dejar como está
    
    content = re.sub(r'!\[([^\]]*)\]\(([^)]+)\)', replace_markdown_images, content)
    
    # Escribir archivo procesado
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(content)

if __name__ == '__main__':
    if len(sys.argv) != 4:
        print("Uso: script.py <archivo.md> <vault_path> <output.md>")
        sys.exit(1)
    
    process_markdown(sys.argv[1], sys.argv[2], sys.argv[3])
PYTHON_END
)

# Guardar el script Python temporalmente
PYTHON_SCRIPT=$(mktemp --suffix=.py)
echo "$PYTHON_PROCESSOR" >"$PYTHON_SCRIPT"

# Función para convertir MD a PDF con soporte de imágenes usando Python
convert_md_to_pdf_pandoc() {
  local md_file="$1"
  local pdf_file="$2"
  local vault_path="$3"

  # Crear archivo temporal procesado
  local temp_md
  temp_md="$(mktemp --suffix=.md)"

  # Procesar con Python
  python3 "$PYTHON_SCRIPT" "$md_file" "$vault_path" "$temp_md"

  # Convertir con Pandoc
  pandoc "$temp_md" -o "$pdf_file" \
    --pdf-engine=xelatex \
    --variable=geometry:margin=2.5cm \
    --variable=fontsize=11pt \
    --variable=mainfont="DejaVu Sans" \
    --highlight-style=tango \
    --standalone \
    --resource-path="$vault_path" \
    2>/dev/null

  local result=$?

  # Limpiar archivo temporal
  rm -f "$temp_md"

  return $result
}

# Función alternativa usando weasyprint
convert_md_to_pdf_weasyprint() {
  local md_file="$1"
  local pdf_file="$2"
  local vault_path="$3"

  local temp_html
  temp_html="$(mktemp --suffix=.html)"
  local temp_md
  temp_md="$(mktemp --suffix=.md)"

  # Procesar con Python
  python3 "$PYTHON_SCRIPT" "$md_file" "$vault_path" "$temp_md"

  # Convertir a HTML con Pandoc
  pandoc "$temp_md" -o "$temp_html" \
    --standalone \
    --self-contained \
    --embed-resources \
    --resource-path="$vault_path" \
    2>/dev/null

  # Añadir CSS
  local css_style='<style>body{font-family:Arial,sans-serif;max-width:800px;margin:40px auto;line-height:1.6}img{max-width:100%;height:auto;display:block;margin:20px 0}</style>'
  sed -i "s|</head>|${css_style}</head>|" "$temp_html"

  # Convertir HTML a PDF
  weasyprint "$temp_html" "$pdf_file" 2>/dev/null

  local result=$?

  # Limpiar temporales
  rm -f "$temp_html" "$temp_md"

  return $result
}

# Detectar qué herramienta de conversión está disponible
detect_converter() {
  if ! command -v python3 &>/dev/null; then
    echo "none"
    return
  fi

  if command -v weasyprint &>/dev/null && command -v pandoc &>/dev/null; then
    echo "weasyprint"
  elif command -v pandoc &>/dev/null && command -v xelatex &>/dev/null; then
    echo "pandoc"
  else
    echo "none"
  fi
}

# Verificar si una carpeta es de imágenes
is_image_folder() {
  local folder_name="$1"
  local base_name
  base_name=$(basename "$folder_name")

  for img_folder in "${IMAGE_FOLDERS[@]}"; do
    if [[ "$base_name" == "$img_folder" ]] || [[ "$base_name" =~ ^${img_folder} ]]; then
      return 0
    fi
  done
  return 1
}

# Verificar si el archivo .md es más reciente que el .pdf correspondiente
needs_update() {
  local md_file="$1"
  local pdf_file="$2"

  # Si el PDF no existe, necesita actualización
  if [[ ! -f "$pdf_file" ]]; then
    return 0
  fi

  # Comparar timestamps: si .md es más reciente que .pdf, necesita actualización
  if [[ "$md_file" -nt "$pdf_file" ]]; then
    return 0
  fi

  # No necesita actualización
  return 1
}

# Función principal para procesar una bóveda
process_vault() {
  local vault_path="$1"
  local vault_name
  vault_name="$(basename "$vault_path")"
  local parent_dir
  parent_dir="$(dirname "$vault_path")"
  local pdf_vault_path="${parent_dir}/${vault_name}_PDF"

  echo "=================================================="
  echo "Procesando bóveda: $vault_path"
  echo "Destino PDF: $pdf_vault_path"
  echo "=================================================="

  local is_first_run=false

  # Crear directorio de destino si no existe
  if [[ ! -d "$pdf_vault_path" ]]; then
    mkdir -p "$pdf_vault_path"
    echo "  ✓ Primera ejecución: Carpeta PDF creada"
    is_first_run=true
  else
    echo "  ✓ Carpeta PDF existe: modo incremental activado"
  fi

  # SOLO en la primera ejecución: copiar toda la estructura y archivos
  if $is_first_run; then
    echo ""
    echo "Primera ejecución: Copiando estructura completa..."

    # Copiar estructura de directorios (excepto carpetas de imágenes y .obsidian)
    find "$vault_path" -type d -not -path "*/.obsidian*" -not -path "*/.git*" | while read dir; do
      local rel_path="${dir#$vault_path/}"

      if [[ "$rel_path" == "$vault_path" ]]; then
        continue
      fi

      if is_image_folder "$dir"; then
        continue
      fi

      mkdir -p "$pdf_vault_path/$rel_path"
    done

    # Copiar TODOS los archivos que NO sean .md (incluyendo PDFs existentes)
    echo "Copiando archivos existentes..."
    local copied_files=0
    find "$vault_path" -type f -not -name "*.md" -not -path "*/.obsidian*" | while read file; do
      local rel_path="${file#$vault_path/}"

      # Verificar si el archivo está dentro de una carpeta de imágenes
      local skip_file=false
      for img_folder in "${IMAGE_FOLDERS[@]}"; do
        if [[ "$rel_path" =~ /$img_folder/ ]] || [[ "$rel_path" =~ ^$img_folder/ ]]; then
          skip_file=true
          break
        fi
      done

      if $skip_file; then
        continue
      fi

      local dest_file="$pdf_vault_path/$rel_path"
      local dest_dir
      dest_dir="$(dirname "$dest_file")"

      mkdir -p "$dest_dir"
      cp -p "$file" "$dest_file" 2>/dev/null
      if [[ $? -eq 0 ]]; then
        copied_files=$((copied_files + 1))
      fi
    done
    echo "  ✓ Archivos copiados: $copied_files"
  fi

  # Procesar archivos .md (solo los modificados o nuevos)
  echo ""
  echo "Analizando archivos .md para conversión..."
  local total_md
  total_md=$(find "$vault_path" -type f -name "*.md" -not -path "*/.obsidian*" -not -path "*/.git*" | wc -l)
  local current=0
  local updated=0
  local skipped=0
  local failed=0
  local new_files=0

  echo "Archivos .md encontrados: $total_md"
  echo ""

  find "$vault_path" -type f -name "*.md" -not -path "*/.obsidian*" -not -path "*/.git*" | while read md_file; do
    current=$((current + 1))
    local rel_path="${md_file#$vault_path/}"
    local pdf_file="$pdf_vault_path/${rel_path%.md}.pdf"
    local pdf_dir
    pdf_dir="$(dirname "$pdf_file")"

    # Verificar si necesita actualización
    if ! needs_update "$md_file" "$pdf_file"; then
      echo "[$current/$total_md] ⊘ Saltando (no modificado): $rel_path"
      skipped=$((skipped + 1))
      continue
    fi

    # Crear directorio si no existe
    mkdir -p "$pdf_dir"

    # Determinar si es nuevo o actualizado
    local action="Actualizando"
    if [[ ! -f "$pdf_file" ]]; then
      action="Creando nuevo"
      new_files=$((new_files + 1))
    fi

    echo "[$current/$total_md] ⟳ $action: $rel_path"

    # Eliminar PDF antiguo si existe
    [[ -f "$pdf_file" ]] && rm -f "$pdf_file"

    # Convertir según herramienta disponible
    local conversion_result=1
    case "$CONVERTER" in
    weasyprint)
      convert_md_to_pdf_weasyprint "$md_file" "$pdf_file" "$vault_path"
      conversion_result=$?
      ;;
    pandoc)
      convert_md_to_pdf_pandoc "$md_file" "$pdf_file" "$vault_path"
      conversion_result=$?
      ;;
    *)
      echo "ERROR: No hay herramienta de conversión disponible"
      return 1
      ;;
    esac

    if [[ $conversion_result -eq 0 ]] && [[ -f "$pdf_file" ]] && [[ -s "$pdf_file" ]]; then
      echo "  ✓ PDF generado exitosamente"
      updated=$((updated + 1))
    else
      echo "  ✗ Error al crear PDF"
      failed=$((failed + 1))
      # Limpiar PDF vacío si existe
      [[ -f "$pdf_file" ]] && rm -f "$pdf_file"
    fi
  done

  # Detectar y eliminar PDFs huérfanos (cuyo .md fue eliminado)
  echo ""
  echo "Buscando PDFs huérfanos (sin .md correspondiente)..."
  local orphaned=0
  find "$pdf_vault_path" -type f -name "*.pdf" | while read pdf_file; do
    local rel_path="${pdf_file#$pdf_vault_path/}"
    local corresponding_md="$vault_path/${rel_path%.pdf}.md"

    if [[ ! -f "$corresponding_md" ]]; then
      # Verificar que no sea un PDF original (que existía en la bóveda original)
      local original_pdf="$vault_path/$rel_path"
      if [[ ! -f "$original_pdf" ]]; then
        echo "  ✗ Eliminando PDF huérfano: $rel_path"
        rm -f "$pdf_file"
        orphaned=$((orphaned + 1))
      fi
    fi
  done

  echo ""
  echo "=================================================="
  echo "✓ Bóveda procesada: $vault_name"
  echo "  Ubicación: $pdf_vault_path"
  echo "  PDFs nuevos: $new_files"
  echo "  PDFs actualizados: $updated"
  echo "  PDFs sin cambios: $skipped"
  echo "  PDFs huérfanos eliminados: $orphaned"
  echo "  Fallos en conversión: $failed"
  echo "=================================================="
  echo ""
}

# Verificar dependencias
if ! command -v python3 &>/dev/null; then
  echo "ERROR: Python3 no está instalado"
  echo "Instala con: sudo apt install python3"
  exit 1
fi

# Detectar herramienta de conversión disponible
CONVERTER=$(detect_converter)

if [[ "$CONVERTER" == "none" ]]; then
  echo "ERROR: No se encontró ninguna herramienta de conversión MD a PDF"
  echo ""
  echo "Por favor, instala una de las siguientes opciones:"
  echo ""
  echo "  OPCIÓN RECOMENDADA (mejor manejo de imágenes):"
  echo "  =============================================="
  echo "  WeasyPrint + Pandoc:"
  echo "    sudo apt install pandoc python3-pip"
  echo "    pip3 install weasyprint"
  echo ""
  echo "  OPCIÓN ALTERNATIVA:"
  echo "  ==================="
  echo "  Pandoc + XeLaTeX:"
  echo "    sudo apt install pandoc texlive-xetex texlive-fonts-recommended"
  echo ""
  rm -f "$PYTHON_SCRIPT"
  exit 1
fi

echo "=================================================="
echo "Sincronizador Incremental de Bóvedas Obsidian"
echo "=================================================="
echo "Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
echo "Herramienta: $CONVERTER"
if [[ "$CONVERTER" == "weasyprint" ]]; then
  echo "  ✓ WeasyPrint (mejor soporte para imágenes)"
fi
echo ""

# Verificar que el directorio base existe
if [[ ! -d "$BASE_DIR" ]]; then
  echo "Error: El directorio $BASE_DIR no existe."
  rm -f "$PYTHON_SCRIPT"
  exit 1
fi

echo "Buscando bóvedas de Obsidian en: $BASE_DIR"
echo ""

# Buscar directorios con .obsidian (bóvedas)
vault_count=0
find "$BASE_DIR" -maxdepth 3 -type d -name ".obsidian" 2>/dev/null | while read obsidian_dir; do
  vault_path="$(dirname "$obsidian_dir")"
  process_vault "$vault_path"
  vault_count=$((vault_count + 1))
done

# Limpiar script Python temporal
rm -f "$PYTHON_SCRIPT"

echo "=================================================="
echo "Sincronización completada."
echo "=================================================="º
