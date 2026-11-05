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

Deployment, StatefulSet, DaemonSet, Service, Headless Service, Ingress, HPA, PDB, PVC, ConfigMap, Secret, ExternalSecret opcional, RBAC, ServiceAccount, NetworkPolicy, Job, CronJob, ServiceMonitor e `extraObjects`.

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
