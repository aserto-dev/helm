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
{{- with (.Values.directory).remote -}}
address: {{ .address }}
{{- if .tenantID }}
tenant_id: {{ .tenantID }}
{{- end }}
{{- if .apiKey }}
api_key: {{ .apiKey }}
{{- else if (.apiKeySecret).name -}}
api_key: "${DIRECTORY_API_KEY}"
{{- end }}
{{- if .skipTLSVerification }}
insecure: true
{{- end }}
{{- if not (empty .caCert | and (empty .caCertSecret)) }}
ca_cert_path: /directory-certs/{{ (.caCertSecret).key | default "tls.crt" }}
{{- end }}
{{- if not (empty .additionalHeaders) }}
headers:
  {{- toYaml .additionalHeaders | toYaml | nindent 2 }}
{{- end }}
{{- end }}
{{- end }}

{{- define "topaz.remoteDirectoryCertVolume" -}}
{{- $name := printf "%s-remote-ca" (include "topaz.fullname" .) -}}
{{- with (.Values.directory).remote -}}
{{- if .caCert -}}
- name: remote-certs
  configMap:
    name: {{ $name }}
{{- else if (.caCertSecret).name -}}
- name: remote-certs
  secret:
    secretName: {{ .caCertSecret.name }}
{{- end }}
{{- end }}
{{- end }}

{{- define "topaz.remoteDirectoryCertVolumeMount" -}}
{{- with (.Values.directory).remote -}}
{{- if .caCert | or (.caCertSecret).name -}}
- name: remote-certs
  mountPath: /directory-certs
  readOnly: true
{{- end }}
{{- end }}
{{- end }}

{{/*
{{- end }}
{{- end }}
{{- end }}

{{/*
Topaz API key configuration
*/}}
{{- define "topaz.apiKeys" -}}
{{- $keys := list }}
{{- range (.Values.auth).apiKeys }}
  {{- if .key -}}
    {{- $keys = append $keys .key }}
  {{- else if .secretName -}}
    {{- $secretKey := .secretKey | default "api-key" }}
    {{- $varName := printf "${API_KEY_%s_%s}" .secretName $secretKey | upper | replace "-" "_" }}
    {{- $keys = append $keys $varName }}
  {{- end}}
{{- end }}
{{- $keys | toYaml }}
{{- end }}

{{- define "topaz.apiKeysEnv" -}}
{{- $keys := list -}}
{{- range (.Values.auth).apiKeys -}}
  {{- if .secretName -}}
    {{- $keys = append $keys . }}
  {{- end -}}
{{- end -}}
{{- range $keys -}}
{{- $secretKey := .secretKey | default "api-key" -}}
  - name: {{ printf "API_KEY_%s_%s" .secretName $secretKey | upper | replace "-" "_" }}
    valueFrom:
      secretKeyRef:
        name: {{ .secretName }}
        key: {{ $secretKey }}
{{- end -}}
{{- end -}}

{{- define "topaz.discoveryKey" -}}
{{- if .apiKey -}}
{{- .apiKey }}
{{- else if (.apiKeySecret | and .apiKeySecret.name) -}}
"${DISCOVERY_API_KEY}"
{{- else }}
{{ fail "either apiKey or apiKeySecret must be set in opa.policy.discovery" }}
{{- end }}
{{- end }}

{{- define "topaz.edgeKey" -}}
{{- if .apiKey -}}
{{- .apiKey -}}
{{- else if (.apiKeySecret | and .apiKeySecret.name) -}}
"${EDGE_API_KEY}"
{{- end }}
{{- end }}

{{- define "topaz.edgeKeyEnv" -}}
{{- with (((.Values.directory).edge).sync).apiKeySecret -}}
- name: EDGE_API_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .name }}
      key: {{ .key | default "api-key" }}
{{- end }}
{{- end }}

{{- define "topaz.ociCredentials" -}}
{{- if (.apiKeySecret).name -}}
"${REGISTRY_API_KEY}"
{{- else if .user -}}
{{ printf "%s:%s" .user .apiKey }}
{{- else -}}
{{ .apiKey }}
{{- end }}
{{- end }}

{{- define "topaz.svcDependencies" -}}
{{- $deps := dict "reader" "model" "writer" "model" "importer" "model" "authorizer" "reader" "console" "authorizer" -}}
{{- if $.remote }}
  {{- $deps = unset $deps "authorizer" }}
{{- end }}
{{- $dep := get $deps .service -}}
{{- if $dep -}}
needs:
  - {{ $dep }}
{{- end }}
{{- end }}

{{- define "topaz.grpcService" -}}
{{- $values := first . -}}
{{- $svc := last . -}}
{{- $global := $values.http -}}
{{- $cfg := merge (dig $svc "grpc" dict $values.serviceOverrides) $values.grpc -}}
listen_address: 0.0.0.0:{{ ($values.ports).grpc | default "8282" }}
connection_timeout_seconds: {{ $cfg.connectionTimeoutSec | default "2" }}
{{- end }}


{{- define "topaz.gatewayService" -}}
{{- $values := first . -}}
{{- $svc := last . -}}
{{- $cfg := merge (dig $svc "http" dict $values.serviceOverrides) $values.http -}}
listen_address: 0.0.0.0:{{ ($values.ports).https | default "8383" }}

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
{{- $services := list "authorizer" -}}
{{- if empty ((.Values.directory).remote).address -}}
{{- $services = concat $services (list "model" "reader") |
                concat (((.Values.directory).edge).services | default list) }}
{{- end }}
{{- if .Values.console.enabled }}
  {{- $services = append $services "console" }}
{{- end }}
{{- $services | toJson }}
{{- end }}
