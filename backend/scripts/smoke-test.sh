#!/usr/bin/env bash
set -e
BASE_URL=${BASE_URL:-http://localhost:8080}
echo "[*] /health"; curl -sS "${BASE_URL}/health"
echo "\n[*] /api/paywall"; curl -sS "${BASE_URL}/api/paywall?lang=en-US"
echo "\n[*] /api/validate-receipt (dummy)"; curl -sS -X POST "${BASE_URL}/api/validate-receipt" -H "Content-Type: application/json" -d '{"receiptData":"dummy","appAccountToken":"test-uuid"}' || true
echo "\nDone."
