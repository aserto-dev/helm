{{/*
Expand the name of the chart.
*/}}
{{- define "controller.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "controller.fullname" -}}
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
{{- define "controller.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "controller.labels" -}}
helm.sh/chart: {{ include "controller.chart" . }}
{{ include "controller.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "controller.selectorLabels" -}}
app.kubernetes.io/name: {{ include "controller.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "controller.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "controller.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "controller.tenantKeys" -}}
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


{{- define "controller.rootClient" -}}
address: localhost:{{ include "aserto-lib.grpcPort" . }}
tenant_id: {{ include "aserto-lib.rootDirectoryTenantID" . }}
{{- if (include "aserto-lib.grpcConfig" . | fromYaml).certSecret }}
ca_cert_path: /grpc-certs/ca.crt
{{- else }}
no_tls: true
{{- end }}
{{- end }}

{{- define "controller.adminKeysConfigMapName" -}}
{{ ((.Values.sshAdminKeys).configMap).name | default
	(printf "%s-admin-keys" (include "controller.fullname" .)) }}
{{- end }}

{{- define "controller.adminKeysConfigMapKey" -}}
{{ ((.Values.sshAdminKeys).configMap).key | default "authorized_keys" }}
{{- end }}

