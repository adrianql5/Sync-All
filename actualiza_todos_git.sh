#!/bin/bash
# Copyright (c) 2025 Adrián Quiroga Linares Lectura y referencia permitidas; reutilización y plagio prohibidos

BASE_DIRS=(
  "$HOME/Escritorio"
  "$HOME/Hackatones"
  "$HOME/ProyectosPersonales"
)

for BASE_DIR in "${BASE_DIRS[@]}"; do
  [ ! -d "$BASE_DIR" ] && continue

  find "$BASE_DIR" -type d -name ".git" 2>/dev/null | while read gitdir; do
    REPO_DIR="$(dirname "$gitdir")"
    cd "$REPO_DIR" || continue

    # Solo verificar si hay cambios (super rápido)
    if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
      git add -A
      git commit -m "Auto: $(date '+%Y-%m-%d %H:%M')" -q
      git push -q 2>/dev/null && echo "✓ $REPO_DIR" || echo "⚠ $REPO_DIR"
    fi
  done
done
