#!/usr/bin/env bash
# Проверка окружения для варианта A.
set -uo pipefail
miss=0
# ИСПРАВЛЕНО: у jq нет подкоманды `version` (скрипт печатал ложную ошибку
# `jq: error: version/0 is not defined`). Теперь команда получения версии
# передаётся 4-м аргументом; по умолчанию остаётся прежнее поведение `<tool> version`.
check() { local vcmd="${4:-$1 version}"; if command -v "$1" >/dev/null 2>&1; then printf '  ✓ %-12s %s\n' "$1" "$($vcmd 2>&1 | head -n1)"; else printf '  ✗ %-12s НЕТ - %s\n' "$1" "$2"; [ "$3" = req ] && miss=$((miss+1)); fi; }
echo; echo "Инструменты стенда (вариант A)"; echo
check helm        "https://helm.sh/docs/intro/install/"                    req
check kustomize   "входит в kubectl: kubectl kustomize"                    opt
check kubectl     "https://kubernetes.io/docs/tasks/tools/"                req
check kubeconform "brew install kubeconform"                               opt
check conftest    "brew install conftest"                                  opt
check jq          "brew install jq"                                        req "jq --version"
echo
[ "$miss" -gt 0 ] && { echo "Не хватает обязательных инструментов: $miss"; exit 1; }
echo "Окружение готово. Дальше: ./scripts/score.sh --save baseline"
