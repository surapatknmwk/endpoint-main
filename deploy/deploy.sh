#!/usr/bin/env bash
# Build locally, upload to the VPS, restart, and health-check.
# Run from the repo root:  DEPLOY_HOST=<ssh host> ./deploy/deploy.sh [all|backend|frontend]
# The ssh user must be the one that ran setup-server.sh (owns /opt/endpoint and
# /var/www/endpoint, and may run `sudo systemctl restart endpoint` without a password).
set -euo pipefail

HOST="${DEPLOY_HOST:?set DEPLOY_HOST (e.g. an alias from ~/.ssh/config)}"
TARGET="${1:-all}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HEALTH_URL="http://127.0.0.1:8080/endpoint-authen-service/health"

deploy_backend() {
  echo "==> build endpoint-service"
  (cd "$ROOT/endpoint-service" && mvn -q -DskipTests clean package)
  local jar
  jar="$(ls "$ROOT"/endpoint-service/target/endpoint-services-*.jar)"

  echo "==> upload jar"
  scp -q "$jar" "$HOST:/opt/endpoint/app.jar.new"

  echo "==> swap in + restart (previous jar kept as app.jar.prev)"
  ssh "$HOST" 'set -e
    cd /opt/endpoint
    if [ -f app.jar ]; then cp -p app.jar app.jar.prev; fi
    chmod 644 app.jar.new
    mv app.jar.new app.jar
    sudo systemctl restart endpoint'

  echo "==> wait for health"
  for _ in $(seq 1 30); do
    if ssh "$HOST" "curl -sf $HEALTH_URL >/dev/null"; then
      echo "backend is up"
      return
    fi
    sleep 3
  done
  echo "backend did not become healthy -- check: ssh $HOST sudo journalctl -u endpoint -n 100" >&2
  echo "rollback:  ssh $HOST 'cp /opt/endpoint/app.jar.prev /opt/endpoint/app.jar && sudo systemctl restart endpoint'" >&2
  exit 1
}

deploy_frontend() {
  echo "==> build endpoint-webapp"
  (cd "$ROOT/endpoint-webapp" && npm run build)

  echo "==> upload dist/"
  rsync -az --delete --chmod=D755,F644 "$ROOT/endpoint-webapp/dist/" "$HOST:/var/www/endpoint/"
  echo "frontend deployed"
}

case "$TARGET" in
  all) deploy_backend; deploy_frontend ;;
  backend) deploy_backend ;;
  frontend) deploy_frontend ;;
  *) echo "usage: deploy.sh [all|backend|frontend]" >&2; exit 1 ;;
esac
