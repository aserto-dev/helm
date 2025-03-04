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
{{- else if (.apiKeySecret).name }}
api_key: "${DIRECTORY_API_KEY}"
{{- end }}
{{- if .skipTLSVerification }}
insecure: true
{{- end }}
{{- if not (empty .caCert | and (empty .caCertSecret)) }}
ca_cert_path: /directory-certs/{{ (.caCertSecret).key | default "tls.crt" }}
{{- end }}
{{-  with .additionalHeaders }}
headers:
  {{- toYaml . | toYaml | nindent 2 }}
{{- end }}
{{- end }}
{{- end }}


{{- define "topaz.remoteDirectoryKeyEnv" -}}
- name: DIRECTORY_API_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .name }}
      key: {{ .key | default "api-key" }}
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
{{- if .caCert | or (.caCertSecret).name -}}
- name: remote-certs
  mountPath: /directory-certs
  readOnly: true
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
{{- $keys := list }}
{{- range . }}
  {{- if .secretName -}}
    {{- $keys = append $keys . }}
  {{- end }}
{{- end }}
{{- range $keys }}
{{- $secretKey := .secretKey | default "api-key" }}
- name: {{ printf "API_KEY_%s_%s" .secretName $secretKey | upper | replace "-" "_" }}
  valueFrom:
    secretKeyRef:
      name: {{ .secretName }}
      key: {{ $secretKey }}
{{- end }}
{{- end -}}


{{- define "topaz.discoveryKey" -}}
{{- if .apiKey -}}
{{- .apiKey }}
{{- else if (.apiKeySecret | and (.apiKeySecret).name) -}}
"${DISCOVERY_API_KEY}"
{{- else }}
{{ fail "either apiKey or apiKeySecret must be set in opa.policy.discovery" }}
{{- end }}
{{- end }}


{{- define "topaz.discoveryKeyEnv" -}}
- name: DISCOVERY_API_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .name }}
      key: {{ .key | default "api-key" }}
{{- end }}


{{- define "topaz.edgeKey" -}}
{{- if .apiKey -}}
{{- .apiKey -}}
{{- else if (.apiKeySecret | and (.apiKeySecret).name) -}}
"${EDGE_API_KEY}"
{{- end }}
{{- end }}

{{- define "topaz.edgeKeyEnv" -}}
- name: EDGE_API_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .name }}
      key: {{ .key | default "api-key" }}
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
{{- $deps := dict "reader" "model" "writer" "model" "importer" "model" "authorizer" "reader" "console" "authorizer" }}
{{- if $.remote }}
  {{- $deps = unset $deps "authorizer" }}
{{- end }}
{{- get $deps .service }}
{{- end }}


{{- define "topaz.grpcService" -}}
{{- $values := first . -}}
{{- $svc := last . -}}
{{- $global := $values.http -}}
{{- $cfg := merge (dig $svc "grpc" dict $values.serviceOverrides) $values.grpc -}}
listen_address: 0.0.0.0:{{ ($values.ports).grpc | default "8282" }}
connection_timeout_seconds: {{ $cfg.connectionTimeoutSec | default "2" }}
{{- with ($values.tls).grpc }}
certs:
  tls_key_path: /grpc-certs/tls.key
  tls_cert_path: /grpc-certs/tls.crt
  tls_ca_cert_path: /grpc-certs/ca.crt
{{- end }}
{{- end }}


{{- define "topaz.gatewayService" -}}
{{- $values := first . -}}
{{- $svc := last . -}}
{{- $cfg := merge (dig $svc "http" dict $values.serviceOverrides) $values.http -}}
listen_address: 0.0.0.0:{{ ($values.ports).http | default "8383" }}

{{- if $cfg.domain }}
fqdn: {{ $cfg.domain }}
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

read_timeout: {{ $cfg.readTimeout | default "2s" }}
read_header_timeout: {{ $cfg.readHeaderTimeout | default "2s" }}
write_timeout: {{ $cfg.writeTimeout | default "2s" }}
idle_timeout: {{ $cfg.idleTimeout | default "30s" }}
{{- with ($values.tls).http }}
certs:
  tls_key_path: /tls-certs/tls.key
  tls_cert_path: /tls-certs/tls.crt
  tls_ca_cert_path: /tls-certs/ca.crt
{{- end }}
{{- end }}


{{- define "topaz.discoveryResource" -}}
{{- if empty .policyName }}
  {{- fail "opa.policy.discovery.policyName is required" }}
{{- end }}
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


{{- define "topaz.decisionLogger" -}}
{{- with .Values.decisionLogs -}}
{{- if .remote -}}
type: self
config:
  store_directory: "/decisions"
  port: {{ .remote.natsPort | default "4222" }}
  shipper:
    {{- with .remote.shipper | default dict }}
    max_bytes: {{ .maxSpoolSizeMB | default 100 | mul 1024 | mul 1024 }}
    max_batch_size: {{ .maxBatchSize | default "512" }}
    publish_timeout_seconds: {{ .publishTimeoutSec | default "10"}}
    max_inflight_batches: {{ .maxInflightBatches | default "10" }}
    delete_stream_on_done: {{ .deleteStreamOnDone | default "false" }}
    {{- end }}
  scribe:
  {{- with .remote.scribe | default dict }}
    address: {{ .address | default "ems.prod.aserto.com:8443" }}
    tenant_id: {{ .tenantID | required "decisionLogs.remote.scribe.tenantID is required" }}
    {{- if not (.mtlsCert | or .mtlsKey | or .mtlsCertSecretName) }}
      {{ fail "decisionLogs.remote.scribe must contain either mtlsCertSecretName or mtlsCert and mtlsKey" }}
    {{- end }}
    client_cert_path: /scribe-cert/tls.crt
    client_key_path: /scribe-cert/tls.key
    ack_wait_seconds: {{ .ackWaitSec | default "60" }}
    {{- if .skipTLSVerification }}
    insecure: true
    {{- end }}
    {{- with .additionalHeaders }}
    headers:
      {{- toYaml . | toYaml | nindent 6 }}
    {{- end }}
  {{- end }}
{{- else if .file -}}
type: file
config:
  log_file_path: /decisions/decisions.log
  max_file_size_mb: {{ .file.maxFileSizeMB | default "50" }}
  max_file_count: {{ .file.maxFileCount | default "2" }}
{{- else -}}
{{- fail "either decisionLogs.file or decisionLogs.remote must be set" }}
{{- end }}
{{- end }}
{{- end }}


{{- define "topaz.scribeCertVolume" -}}
{{- with ((.Values.decisionLogs).remote).scribe | required "missing required decisionLogs.remote.scribe configuration" -}}
- name: scribe-cert
  secret:
  {{- if .mtlsCert | and .mtlsKey }}
    secretName: {{ include "topaz.fullname" $ }}-scribe-client-cert
  {{- else if .mtlsCertSecretName }}
    secretName: {{ .mtlsCertSecretName }}
  {{- else }}
    {{- fail "decisionLogs.remote.scribe must contain either mtlsCertSecretName or mtlsCert and mtlsKey" }}
  {{- end }}
{{- end }}
{{- end }}


{{- define "topaz.controller" -}}
enabled: true
server:
  {{- with .Values.controller }}
  address: {{ .address | default "relay.prod.aserto.com:8443" }}
  client_cert_path: /controller-cert/tls.crt
  client_key_path: /controller-cert/tls.key
  {{- if .skipTLSVerification }}
  insecure: true
  {{- end }}
  {{- with .additionalHeaders }}
  headers:
    {{- toYaml . | toYaml | nindent 4 }}
  {{- end }}
  {{- end }}
{{- end }}


{{- define "topaz.controllerCertVolume" -}}
{{- with .Values.controller -}}
- name: controller-cert
  secret:
  {{- if .mtlsCert | and .mtlsKey }}
    secretName: {{ include "topaz.fullname" $ }}-controller-client-cert
  {{- else if .mtlsCertSecretName }}
    secretName: {{ .mtlsCertSecretName }}
  {{- else }}
    {{- fail "controller must contain either mtlsCertSecretName or mtlsCert and mtlsKey" }}
  {{- end }}
{{- end }}
{{- end }}

{{- define "topaz.tenantID" -}}
{{- $discoID := (((.Values.opa).policy).discovery).tenantID }}
{{- $edgeID := (((.Values.directory).edge).sync).tenantID }}
{{- if $discoID | and $edgeID | and (eq $discoID $edgeID | not) }}
  {{ fail "opa.policy.discovery.tenantID and directory.edge.sync.tenantID must match" }}
{{- end }}
{{- $discoID | or $edgeID | default "-" | quote }}
{{- end }}


{{- define "topaz.edgePlugin" -}}
{{- with ((.Values.directory).edge).sync -}}
{{- if .address | and (empty (($.Values.directory).remote).address) -}}
aserto_edge:
  addr: {{ .address }}
{{- with include "topaz.edgeKey" . }}
  apikey: {{ . }}
{{- end }}
  enabled: true
  insecure: {{ .skipTLSVerification | default false | toString }}
  sync_interval: {{ .intervalMinutes | default "1" }}
  timeout: {{ .timeoutSeconds | default "5" }}
{{- end }}
{{- end }}
{{- end }}


{{- define "topaz.decisionLogPlugin" -}}
{{- if (.Values.decisionLogs).enabled -}}
aserto_decision_log:
  enabled: true
{{- end }}
{{- end }}

{{- define "topaz.volumeClaimTemplateSpec" -}}
accessModes:
  - ReadWriteOnce
resources:
  requests:
    storage: {{ .storage | required "persistence.storage cannot be empty" }}
{{- if .storageClassName }}
storageClassName: {{ .storageClassName }}
{{- end }}
{{- if .selector }}
selector:
  {{- .selector | toYaml | nindent 4 }}
{{- end }}
{{- end }}
