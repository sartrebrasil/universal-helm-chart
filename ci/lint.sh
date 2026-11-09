#!/usr/bin/env sh
# lint + render de todos os modos do chart (+ kubeconform se instalado) + asserts em ci/test.sh
set -eu
cd "$(dirname "$0")/.."
helm lint .
r() { n=$1; shift; helm template "$n" . "$@" >/dev/null; }
r test-default
r test-sts --set workload.type=statefulset
r test-ds --set workload.type=daemonset
r test-none-job --set workload.type=none --set job.enabled=true --set service.enabled=false
for f in examples/*.yaml; do r "t-$(basename "$f" .yaml)" -f "$f"; done
if command -v kubeconform >/dev/null 2>&1; then
  for f in examples/*.yaml; do
    helm template t . -f "$f" | kubeconform -strict -ignore-missing-schemas -summary
  done
else
  echo "kubeconform não instalado: validação de schema K8s ignorada"
fi
sh ci/test.sh
