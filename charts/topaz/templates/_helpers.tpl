{{/*
Expand the name of the chart.
*/}}
{{- define "topaz.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "topaz.fullname" -}}
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
{{- define "topaz.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "topaz.labels" -}}
helm.sh/chart: {{ include "topaz.chart" . }}
{{ include "topaz.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "topaz.selectorLabels" -}}
app.kubernetes.io/name: {{ include "topaz.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "topaz.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "topaz.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Remote directory configuration
*/}}
{{- define "topaz.remoteDirectory" -}}
address: {{ ((.Values.directory).remote).address }}
{{- if not (empty ((.Values.directory).remote).tenantID) }}
tenant_id: {{ ((.Values.directory).remote).tenantID }}
{{- end }}
{{- if not (empty ((.Values.directory).remote).apiKey) }}
api_key: {{ ((.Values.directory).remote).apiKey }}
{{- end }}
{{- if ((.Values.directory).remote).skipTLSVerification }}
insecure: true
{{- end }}
{{- if not (empty ((.Values.directory).remote).caCert | and (empty ((.Values.directory).remote).caCertSecret)) }}
ca_cert_path: /directory-certs/ca.crt
{{- end }}
{{- if not (empty ((.Values.directory).remote).additionalHeaders) }}
headers:
  {{ toYaml ((.Values.directory).remote).additionalHeaders | toYaml | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Topaz API key configuration
*/}}
{{- define "topaz.apiKeys" -}}
{{- range .Values.auth.apiKeys }}
{{- if .key -}}
"{{ .key }}": root-key
{{- else if .secretName -}}
{{- $secretKey := .secretKey | default "api-key" }}
{{- $varName := printf "${API_KEY_%s_%s}" .secretName $secretKey | upper | replace "-" "_" }}
"{{ $varName }}": root-key
{{- end}}
{{- end }}
{{- end }}

{{- define "topaz.discoveryKey" -}}
{{- if .apiKey -}}
{{- .apiKey }}
{{- else if .apiKeySecret | and .apiKeySecret.name -}}
"${DISCOVERY_API_KEY}"
{{- else }}
{{ fail "either apiKey or apiKeySecret must be set in opa.policy.discovery" }}
{{- end }}
{{- end }}

{{- define "topaz.ociCredentials" -}}
{{- if .apiKeySecret -}}
"${REGISTRY_API_KEY}"
{{- else if .user }}
{{ printf "%s:%s" .user .apiKey }}
{{- else }}
{{ .apiKey }}
{{- end }}
{{- end }}

{{- define "topaz.svcDependencies" -}}
{{- $deps := dict "reader" "model" "writer" "model" "importer" "model" "authorizer" "reader" "console" "authorizer" }}
{{- $dep := get $deps .service }}
{{- if $dep -}}
needs:
  - {{ $dep  }}
{{- end }}
{{- end }}

{{- define "topaz.grpcService" -}}
{{- $values := first . -}}
{{- $svc := last . -}}
{{- $global := $values.http -}}
{{- $cfg := merge (dig $svc "grpc" dict $values.serviceOverrides) $values.grpc -}}
listen_address: 0.0.0.0:{{ $cfg.port | default "8282" }}
connection_timeout_seconds: {{ $cfg.connectionTimeoutSec | default "2" }}
{{- end }}


{{- define "topaz.gatewayService" -}}
{{- $values := first . -}}
{{- $svc := last . -}}
{{- $cfg := merge (dig $svc "http" dict $values.serviceOverrides) $values.http -}}
listen_address: 0.0.0.0:{{ $cfg.port | default "8383" }}

{{- if $cfg.domain }}
fdqn: {{ $cfg.domain }}
{{- end }}

{{- if $cfg.allowedHeaders }}
allowed_headers:
{{- $cfg.allowedHeaders | default list | toYaml | nindent 2 }}
{{- end }}

{{- if $cfg.allowedMethods }}
allowed_methods:
{{- $cfg.allowedMethods | default list | toYaml | nindent 2 }}
{{- end }}

{{- $origins := list "http://localhost:*" "https://localhost:*" }}
{{- if $cfg.domain }}
{{- $origins = append $origins $cfg.domain }}
{{- end }}
{{- $origins = concat $origins ($cfg.additionalAllowedOrigins | default list) }}
allowed_origins:
{{- $origins | toYaml | nindent 2 }}

{{- if $cfg.noTLS }}
http: false
{{- end }}
read_timeout: {{ $cfg.readTimeout | default "2s" }}
read_header_timeout: {{ $cfg.readHeaderTimeout | default "2s" }}
write_timeout: {{ $cfg.writeTimeout | default "2s" }}
idle_timeout: {{ $cfg.idleTimeout | default "30s" }}
{{- end }}

{{- define "topaz.discoveryResource" -}}
{{- printf "%s/%s/opa" .policyName .policyName }}
{{- end }}

{{- define "topaz.enabledServices" -}}
{{- $services := list "authorizer" "model" "reader" |
       concat (((.Values.directory).edge).services | default list) }}
{{- if .Values.console.enabled }}
{{- $services = append $services "console" }}
{{- end }}
{{- $services | toJson }}
{{- end }}
