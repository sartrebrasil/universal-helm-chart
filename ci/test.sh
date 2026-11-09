#!/usr/bin/env sh
# asserts sobre o render (helm-unittest não é requisito)
set -eu
cd "$(dirname "$0")/.."
fail=0
t() { helm template t . "$@" 2>&1; }
ok()  { printf 'ok   %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; fail=1; }
has()  { if printf '%s' "$2" | grep -Eq -- "$3"; then ok "$1"; else bad "$1"; fi; }
hasnt(){ if printf '%s' "$2" | grep -Eq -- "$3"; then bad "$1"; else ok "$1"; fi; }

out=$(t -f examples/values-config-files.yaml)
has   "configFiles: mount por subPath" "$out" 'subPath: application.yaml'
has   "configFiles: checksum no deployment" "$out" 'checksum/config-files'
has   "lifecycle no container" "$out" 'preStop'
has   "image com tpl" "$out" 'image: "ghcr.io/acme/t:1.0.0"'
has   "ingress sem name usa índice" "$out" 'name: t-universal-workload-1'
has   "ingress com servicePort numérico" "$out" 'number: 8080'
has   "commonAnnotations ausente por padrão" "$(t)" 'kind: Deployment'
hasnt "sem configMap/secret: sem checksum" "$(t)" 'checksum/'

out=$(t --set commonAnnotations.team=sre --set service.annotations.a=b)
has   "commonAnnotations no Deployment" "$out" 'team: sre'
has   "annotations específicas do Service" "$out" 'a: b'

out=$(t -f examples/values-migration-job.yaml)
has   "job: hook" "$out" 'helm.sh/hook: pre-install,pre-upgrade'
has   "job: securityContext do chart" "$out" 'readOnlyRootFilesystem: true'
has   "job: component label" "$out" 'app.kubernetes.io/component: job'
hasnt "job: sem probes" "$out" 'livenessProbe'
hasnt "job: sem checksum (template imutável)" "$out" 'checksum/'

out=$(t --set workload.type=none --set job.enabled=true --set 'sidecars[0].name=proxy' --set 'sidecars[0].image=x')
hasnt "job: sidecars não entram" "$out" 'name: proxy'

out=$(t --set workload.type=statefulset --set autoscaling.enabled=true)
hasnt "sts com HPA: sem replicas" "$out" 'replicas: 2'
has   "sts com HPA: HPA alveja StatefulSet" "$out" 'kind: StatefulSet'
hasnt "daemonset: sem HPA" "$(t --set workload.type=daemonset --set autoscaling.enabled=true)" 'HorizontalPodAutoscaler'
has   "service seleciona só o workload" "$(t)" 'app.kubernetes.io/component: workload'
has   "antiAffinity soft" "$(t --set antiAffinityPreset=soft)" 'preferredDuringScheduling'
has   "antiAffinity hard" "$(t --set antiAffinityPreset=hard)" 'requiredDuringScheduling'
has   "karpenter amarra pods ao NodePool" "$(t --set karpenter.enabled=true)" 'karpenter.sh/nodepool: default-t-universal-workload'
has   "httpRoute exige parentRefs" "$(t --set httpRoute.enabled=true)" 'parentRefs é obrigatório'
has   "httpRoute" "$(t --set httpRoute.enabled=true --set 'httpRoute.parentRefs[0].name=gw')" 'kind: HTTPRoute'
has   "podMonitor" "$(t --set podMonitor.enabled=true)" 'kind: PodMonitor'
has   "schema: workload.type inválido" "$(t --set workload.type=nope)" 'workload.type'

[ "$fail" = 0 ] || { echo "testes falharam"; exit 1; }
echo "todos os testes passaram"
