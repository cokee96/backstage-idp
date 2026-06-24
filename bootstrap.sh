#!/usr/bin/env bash
# bootstrap.sh — crea los Secrets necesarios y arranca Backstage
# Ejecutar UNA SOLA VEZ tras clonar el repo
set -euo pipefail

NAMESPACE="backstage"

echo "══════════════════════════════════════════════"
echo " Backstage — bootstrap de secretos"
echo "══════════════════════════════════════════════"

# GitHub token con permisos: repo, read:org, read:user, workflow
if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo ""
  echo "Necesito un GitHub Personal Access Token."
  echo "Créalo en: https://github.com/settings/tokens"
  echo "Permisos necesarios: repo, read:org, read:user, workflow"
  echo ""
  read -r -s -p "Pega el token y pulsa Enter: " GITHUB_TOKEN
  echo ""
fi

# Contraseña de ArgoCD
ARGOCD_PASSWORD=$(kubectl get secret argocd-initial-admin-secret \
  -n argocd -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "")
if [ -z "$ARGOCD_PASSWORD" ]; then
  read -r -s -p "Contraseña de ArgoCD admin: " ARGOCD_PASSWORD
  echo ""
fi

# Token de la Service Account de Kubernetes para el plugin k8s de Backstage
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

kubectl create serviceaccount backstage-k8s-reader -n "$NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: backstage-k8s-reader
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: view
subjects:
  - kind: ServiceAccount
    name: backstage-k8s-reader
    namespace: $NAMESPACE
EOF

K8S_SA_TOKEN=$(kubectl create token backstage-k8s-reader -n "$NAMESPACE" --duration=8760h)

echo ""
echo "Creando Secrets en Kubernetes..."

# Secret con todas las credenciales de la app
kubectl create secret generic backstage-secrets \
  --from-literal=GITHUB_TOKEN="$GITHUB_TOKEN" \
  --from-literal=ARGOCD_PASSWORD="$ARGOCD_PASSWORD" \
  --from-literal=K8S_SA_TOKEN="$K8S_SA_TOKEN" \
  --namespace="$NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

# Secret de PostgreSQL
kubectl create secret generic backstage-postgresql-secret \
  --from-literal=postgres-password="backstage-db-$(openssl rand -hex 8)" \
  --namespace="$NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

# ConfigMap con el app-config.yaml
kubectl create configmap backstage-app-config \
  --from-file=app-config.yaml=app-config/app-config.yaml \
  --namespace="$NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "Aplicando ArgoCD project y root app..."
kubectl apply -f argocd/projects/idp.yaml
kubectl apply -f argocd/apps/root.yaml

echo ""
echo "══════════════════════════════════════════════"
echo " LISTO — Backstage desplegándose..."
echo "══════════════════════════════════════════════"
echo ""
echo "  Espera ~3 minutos a que ArgoCD sincronice."
echo ""
echo "  Luego registra el catálogo:"
echo "    ./register-catalog.sh"
echo ""
echo "  Luego abre la UI:"
echo "    kubectl port-forward svc/backstage -n backstage 7007:7007"
echo "    http://localhost:7007"
echo ""
echo "  Login: haz clic en 'Enter as Guest'"
echo "══════════════════════════════════════════════"
