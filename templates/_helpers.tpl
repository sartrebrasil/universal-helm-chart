{{- define "universal.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "universal.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "universal.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride -}}
{{- end -}}

{{- define "universal.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}
{{- end -}}

{{- define "universal.labels" -}}
helm.sh/chart: {{ include "universal.chart" . }}
app.kubernetes.io/name: {{ include "universal.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- /* name+instance: identifica todos os pods do release (workload, job, cron) e os Services */ -}}
{{- define "universal.instanceLabels" -}}
app.kubernetes.io/name: {{ include "universal.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- /* args: dict "root" . "component" workload|job|cron. O component impede que Service/PDB/HPA peguem pods de Job. */ -}}
{{- define "universal.selectorLabels" -}}
{{ include "universal.instanceLabels" .root }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{- /* args: dict "root" . "extra" <map>. Emite o bloco "annotations:" (commonAnnotations + extra; extra vence) ou nada */ -}}
{{- define "universal.annotations" -}}
{{- $a := merge (dict) (.extra | default dict) (.root.Values.commonAnnotations | default dict) -}}
{{- with $a -}}
annotations:
{{ toYaml . | indent 2 }}
{{- end }}
{{- end -}}

{{- /* hash do conteúdo, só das features ligadas: mudar config/secret reinicia os pods */ -}}
{{- define "universal.checksums" -}}
{{- if .Values.configMap.enabled }}
checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
{{- end }}
{{- if .Values.secret.enabled }}
checksum/secret: {{ include (print $.Template.BasePath "/secret.yaml") . | sha256sum }}
{{- end }}
{{- if .Values.configFiles.enabled }}
checksum/config-files: {{ include (print $.Template.BasePath "/config-files.yaml") . | sha256sum }}
{{- end }}
{{- end -}}

{{- /* args: dict "root" . "checksums" bool. Job não leva checksum: spec.template de Job é imutável */ -}}
{{- define "universal.podAnnotations" -}}
{{- $a := dict -}}
{{- if .checksums }}{{- $a = merge $a (include "universal.checksums" .root | fromYaml) -}}{{- end -}}
{{- $a = merge $a (.root.Values.podAnnotations | default dict) (.root.Values.commonAnnotations | default dict) -}}
{{- with $a -}}
annotations:
{{ toYaml . | indent 2 }}
{{- end }}
{{- end -}}

{{- define "universal.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "universal.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "universal.configMapName" -}}
{{- default (printf "%s-config" (include "universal.fullname" .)) .Values.configMap.name -}}
{{- end -}}

{{- define "universal.secretName" -}}
{{- default (printf "%s-secret" (include "universal.fullname" .)) .Values.secret.name -}}
{{- end -}}

{{- define "universal.image" -}}
{{- printf "%s:%s" (tpl .Values.image.repository .) (.Values.image.tag | default .Chart.AppVersion) -}}
{{- end -}}

{{- /* NodePool é cluster-scoped: o namespace entra no nome */ -}}
{{- define "universal.nodepoolName" -}}
{{- printf "%s-%s" (include "universal.namespace" .) (include "universal.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "universal.probe" -}}
{{- $probe := index . 0 -}}
{{- if $probe.enabled -}}
{{- omit $probe "enabled" | toYaml -}}
{{- end -}}
{{- end -}}

{{- /*
Pod spec compartilhado por workload, Job e CronJob.
args: dict "root" . "component" workload|job|cron "o" <job|cronjob values>
"o" sobrescreve command/args/env/envFrom/resources quando não vazio; probes, lifecycle, sidecars,
topologySpread e antiAffinityPreset só existem no workload (sidecar que não termina trava o Job).
*/ -}}
{{- define "universal.podSpec" -}}
{{- $root := .root -}}
{{- $v := $root.Values -}}
{{- $o := .o | default dict -}}
{{- $isWorkload := eq .component "workload" -}}
{{- $cf := $v.configFiles -}}
{{- $cfOn := and $cf.enabled (or $cf.data $cf.secretData) -}}
terminationGracePeriodSeconds: {{ $v.workload.terminationGracePeriodSeconds }}
serviceAccountName: {{ include "universal.serviceAccountName" $root }}
{{- with $v.imagePullSecrets }}
imagePullSecrets:
{{ toYaml . | nindent 2 }}
{{- end }}
{{- with $v.podSecurityContext }}
securityContext:
{{ toYaml . | nindent 2 }}
{{- end }}
{{- with $v.initContainers }}
initContainers:
{{ toYaml . | nindent 2 }}
{{- end }}
containers:
  - name: {{ include "universal.name" $root }}{{ if not $isWorkload }}-{{ .component }}{{ end }}
    image: {{ include "universal.image" $root | quote }}
    imagePullPolicy: {{ $v.image.pullPolicy }}
    {{- with ($o.command | default $v.command) }}
    command:
{{ toYaml . | nindent 6 }}
    {{- end }}
    {{- with ($o.args | default $v.args) }}
    args:
{{ toYaml . | nindent 6 }}
    {{- end }}
    {{- with $v.containerPorts }}
    {{- if $isWorkload }}
    ports:
{{ toYaml . | nindent 6 }}
    {{- end }}
    {{- end }}
    {{- with ($o.env | default $v.env) }}
    env:
{{ toYaml . | nindent 6 }}
    {{- end }}
    {{- /* o ConfigMap e o Secret do próprio release entram sozinhos, por último: numa chave repetida, vencem os do release */}}
    {{- $envFrom := $o.envFrom | default $v.envFrom }}
    {{- if or $envFrom $v.configMap.enabled $v.secret.enabled }}
    envFrom:
      {{- with $envFrom }}
{{ toYaml . | nindent 6 }}
      {{- end }}
      {{- if $v.configMap.enabled }}
      - configMapRef:
          name: {{ include "universal.configMapName" $root }}
      {{- end }}
      {{- if $v.secret.enabled }}
      - secretRef:
          name: {{ include "universal.secretName" $root }}
      {{- end }}
    {{- end }}
    {{- if $isWorkload }}
    {{- if $v.probes.liveness.enabled }}
    livenessProbe:
{{ include "universal.probe" (list $v.probes.liveness) | nindent 6 }}
    {{- end }}
    {{- if $v.probes.readiness.enabled }}
    readinessProbe:
{{ include "universal.probe" (list $v.probes.readiness) | nindent 6 }}
    {{- end }}
    {{- if $v.probes.startup.enabled }}
    startupProbe:
{{ include "universal.probe" (list $v.probes.startup) | nindent 6 }}
    {{- end }}
    {{- with $v.lifecycle }}
    lifecycle:
{{ toYaml . | nindent 6 }}
    {{- end }}
    {{- end }}
    {{- with ($o.resources | default $v.resources) }}
    resources:
{{ toYaml . | nindent 6 }}
    {{- end }}
    {{- with $v.securityContext }}
    securityContext:
{{ toYaml . | nindent 6 }}
    {{- end }}
    {{- if or $v.persistence.enabled $v.extraVolumeMounts $cfOn }}
    volumeMounts:
      {{- if $v.persistence.enabled }}
      - name: data
        mountPath: {{ $v.persistence.mountPath }}
      {{- end }}
      {{- if $cf.enabled }}
      {{- range $key, $_ := $cf.data }}
      - name: config-files
        mountPath: {{ tpl $cf.path $root }}/{{ $key }}
        subPath: {{ $key }}
        readOnly: true
      {{- end }}
      {{- range $key, $_ := $cf.secretData }}
      - name: config-files-secret
        mountPath: {{ tpl $cf.path $root }}/{{ $key }}
        subPath: {{ $key }}
        readOnly: true
      {{- end }}
      {{- end }}
      {{- with $v.extraVolumeMounts }}
{{ toYaml . | nindent 6 }}
      {{- end }}
    {{- end }}
{{- if $isWorkload }}
{{- with $v.sidecars }}
{{ toYaml . | nindent 2 }}
{{- end }}
{{- end }}
{{- if or $v.persistence.enabled $v.extraVolumes $cfOn }}
volumes:
  {{- if $v.persistence.enabled }}
  - name: data
    persistentVolumeClaim:
      claimName: {{ default (printf "%s-data" (include "universal.fullname" $root)) $v.persistence.existingClaim }}
  {{- end }}
  {{- if and $cf.enabled $cf.data }}
  - name: config-files
    configMap:
      name: {{ include "universal.fullname" $root }}-config-files
  {{- end }}
  {{- if and $cf.enabled $cf.secretData }}
  - name: config-files-secret
    secret:
      secretName: {{ include "universal.fullname" $root }}-config-files
  {{- end }}
  {{- with $v.extraVolumes }}
{{ toYaml . | nindent 2 }}
  {{- end }}
{{- end }}
{{- /* quando o NodePool do chart está ligado, os pods são amarrados a ele; nodeSelector do usuário vence */}}
{{- $nodeSelector := $v.nodeSelector | default dict }}
{{- if $v.karpenter.enabled }}
{{- $nodeSelector = merge (dict "karpenter.sh/nodepool" (include "universal.nodepoolName" $root)) $nodeSelector }}
{{- end }}
{{- with $nodeSelector }}
nodeSelector:
{{ toYaml . | nindent 2 }}
{{- end }}
{{- if $v.affinity }}
affinity:
{{ toYaml $v.affinity | nindent 2 }}
{{- else if and $isWorkload $v.antiAffinityPreset }}
affinity:
  podAntiAffinity:
    {{- $term := dict "labelSelector" (dict "matchLabels" (include "universal.selectorLabels" (dict "root" $root "component" "workload") | fromYaml)) "topologyKey" $v.antiAffinityTopologyKey }}
    {{- if eq $v.antiAffinityPreset "hard" }}
    requiredDuringSchedulingIgnoredDuringExecution:
      {{- list $term | toYaml | nindent 6 }}
    {{- else }}
    preferredDuringSchedulingIgnoredDuringExecution:
      {{- list (dict "weight" 100 "podAffinityTerm" $term) | toYaml | nindent 6 }}
    {{- end }}
{{- end }}
{{- with $v.tolerations }}
tolerations:
{{ toYaml . | nindent 2 }}
{{- end }}
{{- if $isWorkload }}
{{- with $v.topologySpreadConstraints }}
topologySpreadConstraints:
{{ toYaml . | nindent 2 }}
{{- end }}
{{- end }}
{{- with $v.priorityClassName }}
priorityClassName: {{ . }}
{{- end }}
{{- with $v.runtimeClassName }}
runtimeClassName: {{ . }}
{{- end }}
{{- with $v.schedulerName }}
schedulerName: {{ . }}
{{- end }}
{{- with $v.hostAliases }}
hostAliases:
{{ toYaml . | nindent 2 }}
{{- end }}
{{- with $v.dnsConfig }}
dnsConfig:
{{ toYaml . | nindent 2 }}
{{- end }}
{{- with $v.dnsPolicy }}
dnsPolicy: {{ . }}
{{- end }}
{{- end }}
