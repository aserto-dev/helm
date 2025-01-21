{{/*
Expand the name of the chart.
*/}}
{{- define "directory.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "directory.fullname" -}}
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
{{- define "directory.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "directory.labels" -}}
helm.sh/chart: {{ include "directory.chart" . }}
{{ include "directory.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "directory.selectorLabels" -}}
app.kubernetes.io/name: {{ include "directory.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "directory.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "directory.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "directory.tenantKeys" -}}
{{- if empty .name -}}
  {{- fail "tenants[].name is require" }}
{{- end -}}
{{- if .keysSecret -}}
- key: {{ printf "${TENANT_%s_WRITER_KEY}" (replace "." "_" .name | upper) }}
  account: ma:{{ .id }}:directory-client-writer
- key: {{ printf "${TENANT_%s_READER_KEY}" (replace "." "_" .name | upper) }}
  account: ma:{{ .id }}:directory-client-reader
{{- else if .keys -}}
- key: {{ .keys.writer | required "tenants[].keys.writer is required" }}
  account: ma:{{ .id }}:directory-client-writer
- key: {{ .keys.reader | required "tenants[].keys.reader is required" }}
  account: ma:{{ .id }}:directory-client-reader
{{- else -}}
  {{ fail "all tenants must include either 'keys' or 'keysSecret'" }}
{{- end }}
{{- end}}


{{- define "directory.controllerReadKeyEnv" -}}
{{- if .Values.controller.enabled -}}
{{ include "aserto-lib.controllerReadKeyEnv" . }}
{{- end }}
{{- end }}


{{- define "directory.adminKeysConfigMapName" -}}
{{ ((.Values.sshAdminKeys).configMap).name | default (printf "%s-admin-keys" (include "directory.fullname" .)) }}
{{- end }}


{{- define "directory.adminKeysConfigMapKey" -}}
{{ ((.Values.sshAdminKeys).configMap).key | default "authorized_keys" }}
{{- end }}
