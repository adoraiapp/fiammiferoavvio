#!/bin/bash
# FIAMMIFERO · lo script d'avvio COMUNE (piano del bot v2.11, §6-bis P7.3). S8 sceglie solo COME arriva qui.
# Brjan, dalla console di Hetzner, come root: prima `sha256sum /root/avvio.sh` (la sessione confronta tutti i 64
# caratteri), poi `bash /root/avvio.sh`. Non contiene segreti. Le chiavi nascono qui e non escono mai: si mostra
# solo la parte PUBBLICA, come codice QR. Le due righe qui sotto le scrive l'involucro (bot/server/involucri).
set -euo pipefail
umask 022
COMMIT_TRADING="9d23967de04fdc6eddb262c5380d136132028948"   # il commit di main di TRADING da installare: 40 caratteri esadecimali
TASTIERA=""       # il rimedio della tastiera trovato in P7.0: vuoto = nessuno, «it» = italiana

S=/home/installa/.ssh
D=/var/lib/fiammifero/avvio
voce() { printf '\n▶ %s\n' "$*"; }
fatto() { printf '✅ %s\n' "$*"; }
muori() { printf '❌ %s\n' "$*" >&2; exit 1; }
come_installa() { runuser -u installa -- env HOME=/home/installa "$@"; }

[ "$(id -u)" = 0 ] || muori "si lancia come root"
[[ "$COMMIT_TRADING" =~ ^[0-9a-f]{40}$ ]] || muori "manca il commit di TRADING (lo scrive l'involucro)"
[ "$TASTIERA" = "@@TASTIERA@@" ] && TASTIERA=""

voce "1 di 8 · SSH spento e mascherato"
systemctl disable --now ssh.socket ssh.service >/dev/null 2>&1 || true
systemctl mask ssh.socket ssh.service >/dev/null
fatto "SSH spento"

if [ -n "$TASTIERA" ]; then
  voce "la tastiera ($TASTIERA), resa permanente"
  sed -i "s/^XKBLAYOUT=.*/XKBLAYOUT=\"$TASTIERA\"/" /etc/default/keyboard
  loadkeys "$TASTIERA" >/dev/null 2>&1 || true
  fatto "tastiera"
fi

voce "2 di 8 · i pacchetti di Ubuntu"
export DEBIAN_FRONTEND=noninteractive
apt-get -q update
apt-get -q -y install git qrencode nftables chrony netcat-openbsd unattended-upgrades needrestart \
  python3-numpy python3-pandas python3-pytest
apt-get -q -y purge apport >/dev/null 2>&1 || true
timedatectl set-timezone Etc/UTC
fatto "pacchetti"

voce "3 di 8 · gli utenti"
id installa >/dev/null 2>&1 || useradd --create-home --home-dir /home/installa --shell /usr/sbin/nologin installa
for u in fiammifero pxnomi pxgithub; do
  id "$u" >/dev/null 2>&1 || useradd --system --no-create-home --home-dir /nonexistent --shell /usr/sbin/nologin "$u"
done
fatto "installa, fiammifero, pxnomi, pxgithub"

voce "4 di 8 · le due chiavi di GitHub del server"
install -d -m 700 -o installa -g installa "$S"
for k in trading stato; do
  [ -f "$S/$k" ] || come_installa ssh-keygen -q -t ed25519 -N "" -C "fiammifero-server-$k" -f "$S/$k"
  chmod 600 "$S/$k"
done
cat > "$S/known_hosts" <<'GITHUB'
github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=
github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=
GITHUB
cat > "$S/config" <<'CONFIG'
Host github-trading
  HostName github.com
  User git
  IdentityFile /home/installa/.ssh/trading
  IdentitiesOnly yes
  HostKeyAlias github.com
  StrictHostKeyChecking yes
  UserKnownHostsFile /home/installa/.ssh/known_hosts
Host github-stato
  HostName github.com
  User git
  IdentityFile /home/installa/.ssh/stato
  IdentitiesOnly yes
  HostKeyAlias github.com
  StrictHostKeyChecking yes
  UserKnownHostsFile /home/installa/.ssh/known_hosts
CONFIG
chown installa:installa "$S/known_hosts" "$S/config"
chmod 644 "$S/known_hosts" "$S/config"
fatto "chiavi nate sul server"

saluto() {   # $1 = nome nel file config, $2 = il saluto che GitHub deve dare
  local uscita
  uscita=$(come_installa ssh -F "$S/config" -T "git@$1" 2>&1 || true)
  [[ "$uscita" == *"$2"* ]]
}
chiave() {   # $1 = chiave, $2 = repository, $3 = la casella «Allow write access», $4 = il link del modulo
  clear || true
  printf '▶ 5 di 8 · chiave «%s» per %s\n' "$1" "$2"
  printf '  Sul Pixel: Lens inquadra il QR → «Copia» → apri %s\n' "$4"
  printf '  Titolo: fiammifero-server · incolla la chiave · «Allow write access»: %s\n\n' "$3"
  qrencode -t ansiutf8 < "$S/$1.pub"
  read -r -p "Quando GitHub l'ha accettata, premi Invio… " _
}
until chiave trading adoraiapp/TRADING "NON spuntata" "https://github.com/adoraiapp/TRADING/settings/keys/new" &&
  saluto github-trading "Hi adoraiapp/TRADING!"; do
  echo "❌ GitHub non riconosce ancora la chiave di TRADING: ricontrolla il link e riprova"; sleep 2
done
fatto "saluto di GitHub per TRADING"
until chiave stato adoraiapp/fiammifero-stato "SPUNTATA" \
  "https://github.com/adoraiapp/fiammifero-stato/settings/keys/new" && saluto github-stato "Hi adoraiapp/fiammifero-stato!"; do
  echo "❌ GitHub non riconosce ancora la chiave dello stato: ricontrolla il link e riprova"; sleep 2
done
fatto "saluto di GitHub per fiammifero-stato"

voce "6 di 8 · l'impronta della chiave che firma lo stato (V7)"
ssh-keygen -l -f "$S/stato.pub" | awk '{print $2}'
echo "📸 Fotografa questa riga: la sessione la confronta e la scrive in STATO-SESSIONE.md"
read -r -p "Premi Invio… " _

voce "7 di 8 · il codice di TRADING al commit $COMMIT_TRADING"
install -d -m 755 /var/lib/fiammifero
rm -rf "$D"
install -d -m 755 -o installa -g installa "$D"
come_installa git -c core.sshCommand="ssh -F $S/config" clone -q --no-checkout \
  git@github-trading:adoraiapp/TRADING.git "$D/trading"
come_installa git -C "$D/trading" merge-base --is-ancestor "$COMMIT_TRADING" origin/main \
  || muori "il commit non sta in main"
come_installa git -C "$D/trading" -c advice.detachedHead=false checkout -q "$COMMIT_TRADING"
fatto "codice preso"

voce "8 di 8 · l'installatore"
bash "$D/trading/bot/server/installa.sh" "$D/trading/bot/server" "$COMMIT_TRADING"
