{{/*
Expand the name of the chart.
*/}}
{{- define "redis-cluster.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "redis-cluster.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version label.
*/}}
{{- define "redis-cluster.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "redis-cluster.labels" -}}
helm.sh/chart: {{ include "redis-cluster.chart" . }}
{{ include "redis-cluster.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "redis-cluster.selectorLabels" -}}
app.kubernetes.io/name: {{ include "redis-cluster.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Service account name
*/}}
{{- define "redis-cluster.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "redis-cluster.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Redis image reference
*/}}
{{- define "redis-cluster.image" -}}
{{- $registry := .Values.global.imageRegistry | default .Values.image.registry -}}
{{- $repo := .Values.image.repository -}}
{{- $tag := .Values.image.tag | toString -}}
{{- if $registry -}}
{{- printf "%s/%s:%s" $registry $repo $tag -}}
{{- else -}}
{{- printf "%s:%s" $repo $tag -}}
{{- end -}}
{{- end }}

{{/*
Metrics exporter image reference
*/}}
{{- define "redis-cluster.metrics.image" -}}
{{- $registry := .Values.global.imageRegistry | default .Values.metrics.image.registry -}}
{{- $repo := .Values.metrics.image.repository -}}
{{- $tag := .Values.metrics.image.tag | toString -}}
{{- if $registry -}}
{{- printf "%s/%s:%s" $registry $repo $tag -}}
{{- else -}}
{{- printf "%s:%s" $repo $tag -}}
{{- end -}}
{{- end }}

{{/*
Secret name for Redis password
*/}}
{{- define "redis-cluster.secretName" -}}
{{- if .Values.auth.existingSecret -}}
{{- .Values.auth.existingSecret -}}
{{- else -}}
{{- include "redis-cluster.fullname" . -}}
{{- end -}}
{{- end }}

{{/*
Key in secret for Redis password
*/}}
{{- define "redis-cluster.secretPasswordKey" -}}
{{- if and .Values.auth.existingSecret .Values.auth.existingSecretPasswordKey -}}
{{- .Values.auth.existingSecretPasswordKey -}}
{{- else -}}
redis-password
{{- end -}}
{{- end }}

{{/*
Headless service name
*/}}
{{- define "redis-cluster.headlessSvcName" -}}
{{- printf "%s-headless" (include "redis-cluster.fullname" .) -}}
{{- end }}

{{/*
Image pull secrets
*/}}
{{- define "redis-cluster.imagePullSecrets" -}}
{{- $pullSecrets := list -}}
{{- range .Values.global.imagePullSecrets -}}
  {{- $pullSecrets = append $pullSecrets . -}}
{{- end -}}
{{- range .Values.image.pullSecrets -}}
  {{- $pullSecrets = append $pullSecrets . -}}
{{- end -}}
{{- if $pullSecrets }}
imagePullSecrets:
  {{- range $pullSecrets }}
  - name: {{ . }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Pod anti-affinity rules
*/}}
{{- define "redis-cluster.podAntiAffinity" -}}
{{- if eq .Values.podAntiAffinityPreset "hard" }}
podAntiAffinity:
  requiredDuringSchedulingIgnoredDuringExecution:
    - labelSelector:
        matchLabels: {{- include "redis-cluster.selectorLabels" . | nindent 10 }}
      topologyKey: kubernetes.io/hostname
{{- else if eq .Values.podAntiAffinityPreset "soft" }}
podAntiAffinity:
  preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 1
      podAffinityTerm:
        labelSelector:
          matchLabels: {{- include "redis-cluster.selectorLabels" . | nindent 12 }}
        topologyKey: kubernetes.io/hostname
{{- end }}
{{- end }}
