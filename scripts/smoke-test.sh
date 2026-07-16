#!/usr/bin/env bash
# =============================================================================
# Post-deploy smoke test — runs against the LIVE deployment.
# Proves the whole stack (EKS + RDS + networking + inter-service call) works:
#   1. wait for the order-service LoadBalancer to be healthy
#   2. create a customer (via customer-service, reached by port-forward)
#   3. create an order for that customer (via the public order LoadBalancer)
#   4. assert both calls return a body with an id
# Requires: kubectl (configured), curl, jq.
# =============================================================================
set -euo pipefail

echo "==> Resolving order-service LoadBalancer hostname..."
LB=""
for i in $(seq 1 30); do
  LB=$(kubectl get svc order-service-svc -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
  if [ -n "$LB" ]; then break; fi
  echo "   waiting for LoadBalancer to be assigned... ($i/30)"
  sleep 15
done
if [ -z "$LB" ]; then
  echo "ERROR: LoadBalancer hostname never appeared." >&2
  exit 1
fi
echo "    LoadBalancer: $LB"

echo "==> Waiting for order-service /actuator/health to return UP..."
HEALTHY=false
for i in $(seq 1 40); do
  if curl -fsS "http://$LB/actuator/health" 2>/dev/null | grep -q '"status":"UP"'; then
    HEALTHY=true
    break
  fi
  echo "   health not ready yet... ($i/40)"
  sleep 15
done
if [ "$HEALTHY" != "true" ]; then
  echo "ERROR: order-service never became healthy." >&2
  exit 1
fi
echo "    order-service is healthy."

echo "==> Port-forwarding customer-service (internal ClusterIP)..."
kubectl port-forward svc/customer-service-svc 8081:8081 >/dev/null 2>&1 &
PF_PID=$!
# Ensure the port-forward is cleaned up on exit.
trap 'kill $PF_PID 2>/dev/null || true' EXIT
sleep 6

echo "==> Creating a customer..."
CUST_JSON=$(curl -fsS -X POST "http://localhost:8081/customer/createcustomer" \
  -H "Content-Type: application/json" \
  -d '{"name":"CI Smoke Test","email":"ci-smoke@example.com"}')
echo "    response: $CUST_JSON"
CUST_ID=$(echo "$CUST_JSON" | jq -r '.id')
if [ -z "$CUST_ID" ] || [ "$CUST_ID" = "null" ]; then
  echo "ERROR: customer creation did not return an id." >&2
  exit 1
fi
echo "    created customer id=$CUST_ID"

echo "==> Creating an order for customer $CUST_ID via the public LoadBalancer..."
ORDER_JSON=$(curl -fsS -X POST "http://$LB/order/create/$CUST_ID" \
  -H "Content-Type: application/json" \
  -d '{"orderDate":"2026-07-16","amount":42.50}')
echo "    response: $ORDER_JSON"
ORDER_ID=$(echo "$ORDER_JSON" | jq -r '.id')
if [ -z "$ORDER_ID" ] || [ "$ORDER_ID" = "null" ]; then
  echo "ERROR: order creation did not return an id." >&2
  exit 1
fi
echo "    created order id=$ORDER_ID"

echo "==> Verifying the order is retrievable..."
curl -fsS "http://$LB/order/customer/$CUST_ID" | jq -e 'length > 0' >/dev/null
echo ""
echo "SMOKE TEST PASSED — customer + order created and verified end-to-end."
