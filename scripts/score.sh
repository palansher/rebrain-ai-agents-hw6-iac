#!/usr/bin/env bash
# Табло из 8 слоёв проверки для варианта A (Safe IaC packet).
# На старте всё красное - это и есть baseline. Цель задания - довести до 8/8.
#   ./scripts/score.sh
#   ./scripts/score.sh --save baseline   # сохранить логи слоёв в baseline/
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$ROOT"
CHART=charts/launch-control
VALUES="$CHART/values-prod.yaml"
K8S_VERSION="${K8S_VERSION:-1.29.0}"
SAVE=""; [ "${1:-}" = "--save" ] && { SAVE="${2:-baseline}"; mkdir -p "$SAVE"; }
passed=0; total=0
log() { [ -n "$SAVE" ] && cat > "$SAVE/$1.log" || cat >/dev/null; }
pass() { printf '  \033[32m✓\033[0m %s  %s\n' "$1" "${2:-}"; passed=$((passed+1)); total=$((total+1)); }
fail() { printf '  \033[31m✗\033[0m %s  %s\n' "$1" "${2:-}"; total=$((total+1)); }
skip() { printf '  \033[33m–\033[0m %s  %s\n' "$1" "${2:-}"; total=$((total+1)); }
have() { command -v "$1" >/dev/null 2>&1; }
echo; echo "=== score: Safe IaC packet ==="; echo

# 1 helm lint
if out=$(helm lint "$CHART" --values "$VALUES" 2>&1); then pass "helm lint"; else fail "helm lint" "$(printf '%s' "$out" | grep -m1 ERROR | sed 's/.*ERROR//')"; fi
printf '%s' "${out:-}" | log helm-lint

# 2 helm template (рендер)
if render=$(helm template lc "$CHART" --values "$VALUES" 2>&1); then RENDER_OK=1; pass "helm template (рендер)"; else RENDER_OK=0; fail "helm template (рендер)" "$(printf '%s' "$render" | grep -m1 -i error | cut -c1-60)"; fi
printf '%s' "$render" | log helm-template

# 3 kubeconform (helm)
if [ "$RENDER_OK" = 1 ]; then
  if have kubeconform; then printf '%s' "$render" | kubeconform -strict -summary -kubernetes-version "$K8S_VERSION" >/dev/null 2>&1 && pass "kubeconform (helm)" || fail "kubeconform (helm)"; else skip "kubeconform (helm)" "kubeconform не установлен"; fi
else skip "kubeconform (helm)" "нечего валидировать: рендер упал"; fi

# 4 kustomize build
if kout=$(kubectl kustomize overlays/production 2>&1); then KUST_OK=1; pass "kustomize build"; else KUST_OK=0; fail "kustomize build" "$(printf '%s' "$kout" | grep -m1 -i error | cut -c1-60)"; fi
printf '%s' "$kout" | log kustomize

# 5 kubeconform (kustomize)
if [ "$KUST_OK" = 1 ]; then
  if have kubeconform; then printf '%s' "$kout" | kubeconform -strict -summary -kubernetes-version "$K8S_VERSION" >/dev/null 2>&1 && pass "kubeconform (kustomize)" || fail "kubeconform (kustomize)"; else skip "kubeconform (kustomize)" "kubeconform не установлен"; fi
else skip "kubeconform (kustomize)" "нечего валидировать: build упал"; fi

# 6 policy: манифесты
if have conftest && ls policy/*.rego >/dev/null 2>&1 && [ "$RENDER_OK" = 1 ]; then
  printf '%s' "$render" | conftest test - --policy policy/ >/dev/null 2>&1 && pass "policy: манифесты" || fail "policy: манифесты"
else fail "policy: манифесты" "правил нет - напишите свои в policy/"; fi

# 7 policy: terraform plan
if have conftest && ls policy/*.rego >/dev/null 2>&1; then
  conftest test terraform/plan.json --policy policy/ >/dev/null 2>&1 && pass "policy: terraform plan" || fail "policy: terraform plan"
else fail "policy: terraform plan" "правил нет"; fi

# 8 нет секретов в values
secrets=$(grep -rEc '(adminToken|databasePassword|password):[[:space:]]*["'\'']?[^"'\'' ]' "$CHART"/values*.yaml 2>/dev/null | awk -F: '{s+=$2} END{print s+0}')
if [ "$secrets" -eq 0 ]; then pass "нет секретов в values"; else fail "нет секретов в values" "$secrets подозрительных строк"; fi

echo; echo "  Готово: ${passed}/${total}"
dels=$(jq '[.resource_changes[]|select(.change.actions[]|.=="delete")]|length' terraform/plan.json 2>/dev/null)
tot=$(jq '.resource_changes|length' terraform/plan.json 2>/dev/null)
echo "  В terraform/plan.json: ${tot} изменений, из них с удалением ресурса: ${dels}"; echo
[ "$passed" -eq "$total" ]
