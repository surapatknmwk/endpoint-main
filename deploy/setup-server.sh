#!/usr/bin/env bash
# One-time setup of a fresh Ubuntu 24.04 VPS for endpoint (run as root, from this folder):
#   scp -r deploy <server>:~/ && ssh <server>
#   cd ~/deploy && sudo ./setup-server.sh your-domain.com
# Safe to re-run: every step checks or overwrites its own files.
set -euo pipefail

DOMAIN="${1:?usage: setup-server.sh <domain>}"
HERE="$(cd "$(dirname "$0")" && pwd)"
PG_VERSION=16

[ "$(id -u)" -eq 0 ] || { echo "run as root (sudo)"; exit 1; }

echo "==> packages"
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get -y upgrade
DEBIAN_FRONTEND=noninteractive apt-get -y install \
  openjdk-21-jre-headless "postgresql-$PG_VERSION" postgresql-client \
  ufw fail2ban rsync curl gnupg debian-keyring debian-archive-keyring apt-transport-https

if ! command -v caddy >/dev/null; then
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
    | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
    > /etc/apt/sources.list.d/caddy-stable.list
  apt-get update
  apt-get -y install caddy
fi

echo "==> timezone + journald size"
timedatectl set-timezone Asia/Bangkok
mkdir -p /etc/systemd/journald.conf.d
printf '[Journal]\nSystemMaxUse=200M\n' > /etc/systemd/journald.conf.d/size.conf
systemctl restart systemd-journald

echo "==> swap (2 GB, only if none exists)"
if ! swapon --show | grep -q .; then
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
  echo 'vm.swappiness=10' > /etc/sysctl.d/99-swappiness.conf
  sysctl -p /etc/sysctl.d/99-swappiness.conf
fi

echo "==> firewall"
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 443/udp
ufw --force enable
systemctl enable --now fail2ban

echo "==> PostgreSQL tuning"
install -m 644 "$HERE/postgresql-endpoint.conf" "/etc/postgresql/$PG_VERSION/main/conf.d/endpoint.conf"
systemctl restart postgresql

echo "==> app user + directories"
# The login user running this script (via sudo) owns the deploy targets, so
# deploy.sh can upload without sudo; the app itself runs as 'endpoint' (read-only).
DEPLOY_USER="${SUDO_USER:?run with sudo from your normal login user}"
id endpoint >/dev/null 2>&1 || useradd --system --home /opt/endpoint --shell /usr/sbin/nologin endpoint
install -d -m 755 -o "$DEPLOY_USER" -g endpoint /opt/endpoint
install -d -m 750 -o root -g endpoint /etc/endpoint
install -d -m 755 -o "$DEPLOY_USER" -g "$DEPLOY_USER" /var/www/endpoint
echo "$DEPLOY_USER ALL=(root) NOPASSWD: /usr/bin/systemctl restart endpoint" > /etc/sudoers.d/endpoint-deploy
chmod 440 /etc/sudoers.d/endpoint-deploy
visudo -cf /etc/sudoers.d/endpoint-deploy
# group = deploy user, so backups can be pulled off-box with plain rsync
install -d -m 750 -o postgres -g "$DEPLOY_USER" /var/backups/endpoint
if [ ! -f /etc/endpoint/endpoint.env ]; then
  install -m 640 -o root -g endpoint "$HERE/endpoint.env.example" /etc/endpoint/endpoint.env
fi

echo "==> systemd unit"
install -m 644 "$HERE/endpoint.service" /etc/systemd/system/endpoint.service
systemctl daemon-reload
systemctl enable endpoint

echo "==> Caddy"
sed "s/^example\.com /$DOMAIN /" "$HERE/Caddyfile" > /etc/caddy/Caddyfile
install -d -o caddy -g caddy /var/log/caddy
caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
systemctl reload caddy || systemctl restart caddy

echo "==> nightly DB backup (02:30)"
install -m 755 "$HERE/backup-db.sh" /usr/local/bin/endpoint-backup-db.sh
echo '30 2 * * * postgres /usr/local/bin/endpoint-backup-db.sh' > /etc/cron.d/endpoint-backup

cat <<EOF

Done. Next steps (see deploy/README.md):
  1. Create the DB role + database and load data  (db/README.md, ทาง B)
  2. Fill in /etc/endpoint/endpoint.env
  3. From your machine: DEPLOY_HOST=<server> ./deploy/deploy.sh
EOF
