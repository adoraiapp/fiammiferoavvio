#!/bin/bash
# FIAMMIFERO · riprende l'installazione dove si è fermata l'11/11/2026 (mancava il ramo server-comandi di TRADING,
# ora c'è). Rifà solo l'installatore, con il codice già preso al commit giusto. Nessun segreto qui dentro.
# Brjan: prima `sha256sum riprendi.sh` (la sessione confronta i 64 caratteri), poi `bash riprendi.sh`.
set -euo pipefail
D=/var/lib/fiammifero/avvio/trading
COMMIT=9d23967de04fdc6eddb262c5380d136132028948
[ "$(id -u)" = 0 ] || { echo "❌ si lancia come root"; exit 1; }
IN_USO=$(runuser -u installa -- env HOME=/home/installa git -C "$D" rev-parse HEAD)
[ "$IN_USO" = "$COMMIT" ] || { echo "❌ la copia del codice non è al commit giusto: $IN_USO"; exit 1; }
echo "✅ codice al commit $COMMIT"
bash "$D/bot/server/installa.sh" "$D/bot/server" "$COMMIT"
