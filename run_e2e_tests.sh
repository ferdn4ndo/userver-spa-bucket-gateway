#!/usr/bin/env bash
# Build the image, start the stack with a test website, and verify nginx proxies a request.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

NETWORK_NAME="${NETWORK_NAME:-nginx-proxy}"
CI_PORT="${CI_PORT:-18080}"
export COMPOSE_FILE="docker-compose.yml:.github/docker-compose.ci.yml"

if ! docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
  docker network create "$NETWORK_NAME"
fi

E2E_ENV_BACKUP=""
if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
  :
elif [[ -f .env ]]; then
  E2E_ENV_BACKUP="$(mktemp)"
  cp .env "$E2E_ENV_BACKUP"
fi

cat > .env <<'EOF'
VIRTUAL_HOST=
DEMO_DEPLOY_BUCKET=
DEMO_DEPLOY_REGION=
DEMO_REPO_DOMAIN=
SLS_KEY=
SLS_SECRET=
DEBUG=0
TRAILING_SLASH=0
EOF

mkdir -p websites
cat > websites/ci-e2e.json <<'EOF'
{
  "BUCKET_URL": "example.com",
  "DOMAIN": "gateway.ci.test"
}
EOF

cleanup() {
  docker compose down --remove-orphans 2>/dev/null || true
  rm -f websites/ci-e2e.json
  if [[ -n "${E2E_ENV_BACKUP}" ]] && [[ -f "${E2E_ENV_BACKUP}" ]]; then
    mv "${E2E_ENV_BACKUP}" .env
  fi
}
trap cleanup EXIT

docker compose build
docker compose up --detach
sleep 3

ok=false
for _ in $(seq 1 30); do
  if curl -sf --max-time 5 "http://127.0.0.1:${CI_PORT}/" -H "Host: gateway.ci.test" >/dev/null; then
    ok=true
    break
  fi
  sleep 1
done

if [[ "${ok}" != true ]]; then
  echo "E2E: timeout waiting for gateway on port ${CI_PORT}" >&2
  docker compose logs >&2 || true
  exit 1
fi

echo "E2E: gateway responded successfully"
