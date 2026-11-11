#!/bin/bash
# FIAMMIFERO · applica i file di sistema del codice in uso: è `fiammifero-sistema`, senza dover scrivere il trattino
# (la console di Hetzner lo sbaglia). Mostra la differenza e l'impronta corta, e chiede s/n. Nessun segreto qui dentro.
# Brjan: prima `sha256sum sistema.sh` (la sessione confronta i 64 caratteri), poi `bash sistema.sh`.
set -euo pipefail
ATTESO=ae0a25060ed7c5dfb770866f57f9c0aaa0be1649
IN_USO=$(basename "$(readlink /opt/fiammifero/attuale)")
[ "$IN_USO" = "$ATTESO" ] || { echo "❌ il codice in uso è $IN_USO, non $ATTESO: prima serve l'aggiornamento dal canale"; exit 1; }
echo "✅ codice in uso $ATTESO"
exec /usr/local/sbin/fiammifero-sistema
