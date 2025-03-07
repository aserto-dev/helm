{{/*
Expand the name of the chart.
*/}}
{{- define "registry-proxy.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "registry-proxy.fullname" -}}
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
Create chart name and version as used by the chart label.
*/}}
{{- define "registry-proxy.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "registry-proxy.labels" -}}
helm.sh/chart: {{ include "registry-proxy.chart" . }}
{{ include "registry-proxy.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "registry-proxy.selectorLabels" -}}
app.kubernetes.io/name: {{ include "registry-proxy.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "registry-proxy.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "registry-proxy.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Local cluster address
*/}}
{{- define "registry-proxy.clusterAddress" -}}
{{ include "registry-proxy.fullname" . }}.{{ .Release.Namespace }}.svc.cluster.local:{{ include "aserto-lib.grpcPort" . }}
{{- end }}


{{- define "registry-proxy.gatewayService" }}
{{ include "aserto-lib.httpService" .  }}
{{- $cfg := include "aserto-lib.httpConfig" . | fromYaml }}
allowed_headers:
{{- $cfg.allowed_headers | default (list "Aserto-Tenant-Id" "Authorization" "Content-Type" "Depth") | toYaml | nindent 2 }}
{{- end }}
