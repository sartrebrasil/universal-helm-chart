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

{{- define "universal.selectorLabels" -}}
app.kubernetes.io/name: {{ include "universal.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
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
{{- printf "%s:%s" .Values.image.repository (.Values.image.tag | default .Chart.AppVersion) -}}
{{- end -}}

{{- define "universal.probe" -}}
{{- $probe := index . 0 -}}
{{- if $probe.enabled -}}
{{- omit $probe "enabled" | toYaml -}}
{{- end -}}
{{- end -}}

{{- define "universal.podSpec" -}}
serviceAccountName: {{ include "universal.serviceAccountName" . }}
{{- with .Values.imagePullSecrets }}
imagePullSecrets:
{{ toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.podSecurityContext }}
securityContext:
{{ toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.initContainers }}
initContainers:
{{ toYaml . | nindent 2 }}
{{- end }}
containers:
  - name: {{ include "universal.name" . }}
    image: {{ include "universal.image" . | quote }}
    imagePullPolicy: {{ .Values.image.pullPolicy }}
    {{- with .Values.command }}
    command:
{{ toYaml . | nindent 6 }}
    {{- end }}
    {{- with .Values.args }}
    args:
{{ toYaml . | nindent 6 }}
    {{- end }}
    {{- with .Values.containerPorts }}
    ports:
{{ toYaml . | nindent 6 }}
    {{- end }}
    {{- with .Values.env }}
    env:
{{ toYaml . | nindent 6 }}
    {{- end }}
    {{- with .Values.envFrom }}
    envFrom:
{{ toYaml . | nindent 6 }}
    {{- end }}
    {{- if .Values.probes.liveness.enabled }}
    livenessProbe:
{{ include "universal.probe" (list .Values.probes.liveness) | nindent 6 }}
    {{- end }}
    {{- if .Values.probes.readiness.enabled }}
    readinessProbe:
{{ include "universal.probe" (list .Values.probes.readiness) | nindent 6 }}
    {{- end }}
    {{- if .Values.probes.startup.enabled }}
    startupProbe:
{{ include "universal.probe" (list .Values.probes.startup) | nindent 6 }}
    {{- end }}
    {{- with .Values.resources }}
    resources:
{{ toYaml . | nindent 6 }}
    {{- end }}
    {{- with .Values.securityContext }}
    securityContext:
{{ toYaml . | nindent 6 }}
    {{- end }}
    {{- if or .Values.persistence.enabled .Values.extraVolumeMounts }}
    volumeMounts:
      {{- if .Values.persistence.enabled }}
      - name: data
        mountPath: {{ .Values.persistence.mountPath }}
      {{- end }}
      {{- with .Values.extraVolumeMounts }}
{{ toYaml . | nindent 6 }}
      {{- end }}
    {{- end }}
{{- with .Values.sidecars }}
{{ toYaml . | nindent 2 }}
{{- end }}
{{- if or .Values.persistence.enabled .Values.extraVolumes }}
volumes:
  {{- if .Values.persistence.enabled }}
  - name: data
    persistentVolumeClaim:
      claimName: {{ default (printf "%s-data" (include "universal.fullname" .)) .Values.persistence.existingClaim }}
  {{- end }}
  {{- with .Values.extraVolumes }}
{{ toYaml . | nindent 2 }}
  {{- end }}
{{- end }}
{{- with .Values.nodeSelector }}
nodeSelector:
{{ toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.affinity }}
affinity:
{{ toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.tolerations }}
tolerations:
{{ toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.topologySpreadConstraints }}
topologySpreadConstraints:
{{ toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.priorityClassName }}
priorityClassName: {{ . }}
{{- end }}
{{- with .Values.runtimeClassName }}
runtimeClassName: {{ . }}
{{- end }}
{{- with .Values.schedulerName }}
schedulerName: {{ . }}
{{- end }}
{{- with .Values.hostAliases }}
hostAliases:
{{ toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.dnsConfig }}
dnsConfig:
{{ toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.dnsPolicy }}
dnsPolicy: {{ . }}
{{- end }}
{{- end }}
