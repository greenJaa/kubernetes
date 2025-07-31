#!/bin/bash

set -e

NAMESPACE="dev"
DEPLOYMENT_NAME="nginx-deploy"
PVC_NAME="nfs-pvc"
PV_NAME="nfs-pv"
CONFIGMAP_NAME="nginx-custom-config"
VARIABLES_CONFIGMAP="declare-vars"
DECLARE_VARS_FILE="declare-vars.conf"

echo "==> Checking if namespace '$NAMESPACE' exists..."
if kubectl get namespace "$NAMESPACE" &>/dev/null; then
  echo "✓ Namespace '$NAMESPACE' exists."
else
  kubectl create namespace "$NAMESPACE"
  echo "✓ Namespace '$NAMESPACE' created."
fi

echo "==> Deleting old resources if they exist..."
kubectl delete deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" --ignore-not-found
kubectl delete pvc "$PVC_NAME" -n "$NAMESPACE" --ignore-not-found
kubectl delete pv "$PV_NAME" --ignore-not-found
kubectl delete configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" --ignore-not-found
kubectl delete configmap "$VARIABLES_CONFIGMAP" -n "$NAMESPACE" --ignore-not-found

echo "==> Preparing ConfigMaps..."
if [ ! -f "$DECLARE_VARS_FILE" ]; then
  echo "# Auto-created by install.sh" > "$DECLARE_VARS_FILE"
  echo "✓ Created empty $DECLARE_VARS_FILE"
fi

kubectl create configmap "$CONFIGMAP_NAME" --from-file=nginx.conf=nginx.conf -n "$NAMESPACE"
kubectl create configmap "$VARIABLES_CONFIGMAP" --from-file=variables="$DECLARE_VARS_FILE" -n "$NAMESPACE"

# Test configmaps
echo "==> Verifying ConfigMaps..."
kubectl get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" &>/dev/null && echo "✓ ConfigMap '$CONFIGMAP_NAME' exists." || exit 1
kubectl get configmap "$VARIABLES_CONFIGMAP" -n "$NAMESPACE" &>/dev/null && echo "✓ ConfigMap '$VARIABLES_CONFIGMAP' exists." || exit 1

echo "==> Creating PersistentVolume and PersistentVolumeClaim..."
kubectl apply -f nfs-pv.yaml
kubectl apply -f nfs-pvc.yaml -n "$NAMESPACE"

# Wait and test PV/PVC
echo "==> Waiting for PVC to be bound..."
for i in {1..10}; do
  STATUS=$(kubectl get pvc "$PVC_NAME" -n "$NAMESPACE" -o jsonpath='{.status.phase}')
  if [[ "$STATUS" == "Bound" ]]; then
    echo "✓ PVC '$PVC_NAME' is bound."
    break
  fi
  sleep 2
done

if [[ "$STATUS" != "Bound" ]]; then
  echo "✗ PVC '$PVC_NAME' failed to bind."
  exit 1
fi

echo "==> Deploying nginx from file..."
kubectl apply -f nginx-deploy.yaml -n "$NAMESPACE"

# Verify pod status
echo "==> Verifying nginx pod status..."
for i in {1..10}; do
  POD=$(kubectl get pods -n "$NAMESPACE" -l app=nginx-deploy -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  STATUS=$(kubectl get pod "$POD" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || true)
  if [[ "$STATUS" == "Running" ]]; then
    echo "✓ Pod '$POD' is running."
    break
  fi
  sleep 2
done

if [[ "$STATUS" != "Running" ]]; then
  echo "✗ Pod failed to start (status: $STATUS)"
  kubectl describe pod "$POD" -n "$NAMESPACE"
  exit 1
fi

echo "✅ All done."

