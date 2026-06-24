#!/usr/bin/env bash
# register-catalog.sh — registra las locations del catálogo en Backstage
# Ejecutar cada vez que se reinicia el cluster (hasta que el auto-discovery funcione)
set -euo pipefail

BACKSTAGE_URL="http://localhost:7007"

echo "Esperando a que Backstage esté disponible..."
until curl -s -o /dev/null -w "%{http_code}" "$BACKSTAGE_URL/healthcheck" | grep -q "200"; do
  sleep 3
done
echo "Backstage disponible."

echo "Obteniendo token de sesión..."
TOKEN=$(curl -s -X POST "$BACKSTAGE_URL/api/auth/guest/refresh" \
  -H "Content-Type: application/json" \
  -d '{}' | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('backstageIdentity', {}).get('token', '') or d.get('token', ''))
")

if [ -z "$TOKEN" ]; then
  echo "Error: no se pudo obtener token. ¿Está el port-forward activo?"
  echo "  kubectl port-forward svc/backstage -n backstage 7007:7007 &"
  exit 1
fi

register() {
  local URL="$1"
  echo "Registrando: $URL"
  curl -s -X POST "$BACKSTAGE_URL/api/catalog/locations" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d "{\"type\":\"url\",\"target\":\"$URL\"}" | python3 -c "
import sys, json
d = json.load(sys.stdin)
if 'error' in d:
    print('  ERROR:', d['error'].get('message', d))
else:
    print('  OK — id:', d['location']['id'])
" 2>/dev/null || echo "  (ya registrada o error menor)"
}

register "https://github.com/cokee96/backstage-idp/blob/main/catalog/all-components.yaml"
register "https://github.com/cokee96/backstage-idp/blob/main/templates/new-microservice/template.yaml"

echo ""
echo "Catálogo registrado. Espera ~15 segundos y recarga Backstage."
