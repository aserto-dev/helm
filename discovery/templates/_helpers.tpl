{{/*
Expand the name of the chart.
*/}}
{{- define "discovery.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "discovery.fullname" -}}
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
{{- define "discovery.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "discovery.labels" -}}
helm.sh/chart: {{ include "discovery.chart" . }}
{{ include "discovery.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "discovery.selectorLabels" -}}
app.kubernetes.io/name: {{ include "discovery.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "discovery.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "discovery.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Local cluster address
*/}}
{{- define "discovery.clusterAddress" -}}
{{ include "discovery.fullname" . }}.{{ .Release.Namespace }}.svc.cluster.local:{{ include "aserto-lib.grpcPort" . }}
{{- end }}

{{- define "discovery.bundleDefaults" -}}
{{- with .Values.bundleDefaults | default dict -}}
response_header_timeout_seconds: {{ .responseHeaderTimeoutSeconds | default "60" }}
min_delay_seconds: {{ .minDelaySeconds | default "600" }}
max_delay_seconds: {{ .maxDelaySeconds | default "1200" }}
{{- end }}
{{- end }}

{{- define "discovery.cacheSettings" -}}
{{- with .Values.cacheSettings | default dict -}}
type: {{ .type | default "bigcache" }}
{{- if .cacheConfig  }}
cache_config:
{{ .cacheConfig | toYaml | indent 2 }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Converts a registry URL to an environment variable name.
*/}}
{{- define "discovery.registryTokenEnvVar" }}
{{- printf "REGISTRY_TOKEN_%s" (replace "." "_" . | upper) }}
{{- end }}

{{/*
Returns a list of registries with their configuration.
*/}}
{{- define "discovery.registriesConfig" }}
{{- $regs := list }}
{{- range $url, $cfg := (.Values.registries | required "discovery must have at least one registry configured") }}
{{- $regs = append $regs (dict
  "url" $url
  "scheme" $cfg.scheme
  "token" (printf "${%s}" (include "discovery.registryTokenEnvVar" $url)))
}}
{{- end }}
{{- $regs | toYaml }}
{{- end }}

{{/*
Returns deployment environemt variables that mount registry credentials.
*/}}
{{- define "discovery.registriesEnv" }}
{{- $vars := list }}
{{- range $url, $cfg := (.Values.registries | default dict) }}
{{- $vars = append $vars (dict
  "name" (include "discovery.registryTokenEnvVar" $url)
  "valueFrom" (include "discovery.registryTokenValue" $cfg | fromYaml))
}}
{{- end }}
{{- $vars | toYaml }}
{{- end }}

{{- define "discovery.registryTokenValue" }}
secretKeyRef:
  name: {{ .tokenSecretName }}
  key: {{ .tokenSecretKey | default "token" }}
{{- end }}

