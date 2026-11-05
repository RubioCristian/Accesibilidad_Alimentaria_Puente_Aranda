#!/bin/bash
# Se ejecuta solo la primera vez (volumen vacio). Restaura la base de partida.
set -u
BACKUP=/backup/alimentos_puente_aranda_original.backup
if [ ! -f "$BACKUP" ]; then
  echo "[init] No hay backup en $BACKUP; se crea la base vacia."
  exit 0
fi
echo "[init] Restaurando $BACKUP en $POSTGRES_DB ..."
pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" --no-owner --no-privileges "$BACKUP" 2>&1 | tail -20
echo "[init] Restauracion terminada."
