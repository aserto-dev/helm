{{/*
Expand the name of the chart.
*/}}
{{- define "authorizer.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "authorizer.fullname" -}}
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
{{- define "authorizer.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "authorizer.labels" -}}
helm.sh/chart: {{ include "authorizer.chart" . }}
{{ include "authorizer.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "authorizer.selectorLabels" -}}
app.kubernetes.io/name: {{ include "authorizer.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "authorizer.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "authorizer.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Local cluster address
*/}}
{{- define "authorizer.clusterAddress" -}}
{{ include "authorizer.fullname" . }}.{{ .Release.Namespace }}.svc.cluster.local:{{ include "aserto-lib.grpcPort" . }}
{{- end }}

{{/*
OPA discovery configuration
*/}}
{{- define "authorizer.opaDiscovery" -}}
url: http://{{ include "aserto-lib.discoveryAddress" . }}/api/
credentials:
  bearer:
    token: ${AUTHORIZER_DISCOVERY_ROOT_KEY}
    scheme: basic
{{- with (include "aserto-lib.discoveryCfg" . | fromYaml) }}
{{- if .disableTLSVerification }}
allow_insecure_tls : true
{{- else if .tlsCertSecret }}
tls:
  ca_cert: /discovery-tls-certs/ca.crt
{{- else }}
tls:
  ca_cert: /tls-certs/ca.crt
{{- end }}
{{- end }}
{{- end }}

{{- define "authorizer.gatewayService" -}}
{{ include "aserto-lib.httpService" .  }}
{{- $cfg := include "aserto-lib.httpConfig" . | fromYaml }}
allowed_headers:
{{- $cfg.allowed_headers | default (list "Aserto-Tenant-Id" "Authorization" "Content-Type" "Depth") | toYaml | nindent 2 }}
{{- end }}
