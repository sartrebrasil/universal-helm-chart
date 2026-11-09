# universal-workload Helm Chart

Chart Helm universal para aplicações multi-linguagem em Kubernetes: APIs, frontends, workers, jobs e cronjobs.

## Instalação rápida

```bash
helm upgrade --install minha-api ./universal-helm-chart \
  -f examples/values-api-java-spring.yaml \
  --namespace minha-api --create-namespace
```

## Modos principais

- `workload.type=deployment`: app/API/worker padrão.
- `workload.type=statefulset`: workloads com identidade estável.
- `workload.type=daemonset`: agente por nó.
- `workload.type=none`: útil quando você quer apenas `job.enabled` ou `cronjob.enabled`.
- `job.enabled=true`: job one-shot.
- `cronjob.enabled=true`: execução agendada.

## Recursos incluídos

Deployment, StatefulSet, DaemonSet, Service, Headless Service, Ingress (lista), HTTPRoute (Gateway API), HPA, PDB, PVC, ConfigMap, Secret, ConfigMap/Secret de arquivos (`configFiles`), ExternalSecret opcional, RBAC, ServiceAccount, NetworkPolicy, Job, CronJob, ServiceMonitor, PodMonitor, PrometheusRule, NodePool do Karpenter e `extraObjects`.

## Validar/renderizar

```bash
helm lint ./universal-helm-chart
helm template minha-api ./universal-helm-chart -f examples/values-api-java-spring.yaml
helm template reconcile ./universal-helm-chart -f examples/values-python-cronjob.yaml
```

## Dicas

- Para apps Spring Boot, ajuste probes para `/actuator/health/liveness` e `/actuator/health/readiness`.
- Para workers sem porta HTTP, desligue `service.enabled` e probes HTTP.
- Para jobs/cronjobs, use `workload.type=none` para não criar Deployment.
- Use `extraObjects` para CRDs específicos do seu cluster sem precisar alterar templates.
- `configFiles` monta cada chave de `data` (ConfigMap) e `secretData` (Secret) como arquivo em `configFiles.path`; mudar o conteúdo reinicia os pods. Veja `examples/values-config-files.yaml`.
- `lifecycle` repassa `postStart`/`preStop` ao container (ex.: `preStop` com `sleep` para drenar conexões antes do SIGTERM).
- `image.repository` e `configFiles.path` aceitam `{{ .Release.Name }}`.

## Referência de values

Valores e defaults completos em `values.yaml`; `values.schema.json` valida tipos e enums (`workload.type`, `antiAffinityPreset`, `service.type`…) e rejeita chaves desconhecidas no topo.

| Chave | O que faz |
|---|---|
| `workload.type` | `deployment` \| `statefulset` \| `daemonset` \| `none` |
| `image.repository` / `image.tag` | `repository` aceita `{{ .Release.Name }}`; tag vazia usa `appVersion` |
| `command`, `args`, `env`, `envFrom` | Container principal. Job/CronJob herdam quando o seu próprio campo está vazio |
| `configMap` / `secret` | Viram `envFrom` automaticamente quando `enabled` |
| `configFiles` | Chaves de `data`/`secretData` montadas como arquivos (subPath) em `path` |
| `externalSecrets` | ExternalSecret (ESO) |
| `lifecycle` | `postStart`/`preStop` (só no workload) |
| `probes.{liveness,readiness,startup}` | Qualquer tipo de probe; `enabled` liga/desliga (só no workload) |
| `service`, `headlessService` | Várias portas; `sessionAffinity`, `externalTrafficPolicy`, `loadBalancer*` |
| `ingress` | **Lista** de Ingresses (`name`, `className`, `annotations`, `tls`, `hosts`) |
| `httpRoute` | Gateway API (`parentRefs` obrigatório) |
| `autoscaling` | HPA (CPU, memória, `metrics` v2 livres, `behavior`); só deployment/statefulset |
| `pdb` | `minAvailable`/`maxUnavailable`/`unhealthyPodEvictionPolicy` |
| `antiAffinityPreset`, `topologySpreadConstraints` | Espalhamento entre nós/zonas do workload |
| `persistence` | PVC (ou `existingClaim`) montado em `mountPath` |
| `podSecurityContext`, `securityContext` | Padrão restritivo (non-root, seccomp, rootfs somente leitura); vale também para Job/CronJob |
| `networkPolicy` | Seleciona todos os pods do release |
| `job`, `cronjob` | Reusam o pod spec do chart; `job.hook` recria o Job a cada release |
| `serviceMonitor`, `podMonitor`, `prometheusRule` | Prometheus Operator |
| `karpenter` | NodePool `v1beta1` próprio; os pods são amarrados a ele por `nodeSelector` |
| `commonLabels`, `commonAnnotations` | Aplicados a todos os recursos |
| `extraObjects` | Manifestos livres (aceitam `tpl`) |

## Job e CronJob

Job e CronJob usam o mesmo pod spec do workload (security context, volumes, `configFiles`, `imagePullSecrets`, tolerations…), **sem** probes, lifecycle, sidecars nem portas. Os pods levam `app.kubernetes.io/component: job|cron`, então Service, PDB e HPA nunca os selecionam.

`spec.template` de Job é imutável: sem `job.hook.enabled`, um `helm upgrade` com imagem nova falha enquanto o Job anterior ainda existir (`ttlSecondsAfterFinished`). Com o hook (`pre-install,pre-upgrade`), o Job é recriado a cada release; nesse caso o ServiceAccount, o configMap e o secret do release ainda não existem em `pre-install`, então use `serviceAccount.create=false` ou `job.hook.events=post-install,post-upgrade`. Veja `examples/values-migration-job.yaml`.

## Testes

```bash
sh ci/lint.sh   # helm lint, render de todos os modos/exemplos, kubeconform (se instalado) e ci/test.sh
```
