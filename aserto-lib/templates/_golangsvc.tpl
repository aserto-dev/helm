{{/*
Returns gRPC service options.
*/}}
{{- define "aserto-lib.grpcConfig" }}
{{ include "aserto-lib.mergeGlobal" (list . "grpc") }}
{{- end }}

{{/*
Returns HTTPS service options.
*/}}
{{- define "aserto-lib.httpsConfig" }}
{{ include "aserto-lib.mergeGlobal" (list . "https") }}
{{- end }}

{{/*
Renders gRPC service configuration.
*/}}
{{- define "aserto-lib.grpcService" -}}
listen_address: 0.0.0.0:{{ include "aserto-lib.grpcPort" . }}
connection_timeout_seconds: {{ (include "aserto-lib.grpcConfig" . | fromYaml).connectionTimeoutSec | default "2" }}
certs:
  tls_key_path: '/grpc-certs/tls.key'
  tls_cert_path: '/grpc-certs/tls.crt'
  tls_ca_cert_path: '/grpc-certs/ca.crt'
{{- end }}

{{/*
Renders HTTPS service configuration.
*/}}
{{- define "aserto-lib.httpsService" -}}
listen_address: 0.0.0.0:{{ include "aserto-lib.httpsPort" . }}
certs:
  tls_key_path: '/https-certs/tls.key'
  tls_cert_path: '/https-certs/tls.crt'
  tls_ca_cert_path: '/https-certs/ca.crt'

{{- $cfg := include "aserto-lib.httpsConfig" . | fromYaml }}
allowed_headers:
{{- $cfg.allowed_headers | default (list "Aserto-Tenant-Id" "Authorization" "Content-Type" "Depth") | toYaml | nindent 2 }}
{{- if $cfg.allowed_origins }}
allowed_origins:
{{- $cfg.allowed_origins | toYaml | nindent 2 }}
{{- end }}
read_timeout: {{ $cfg.read_timeout | default "2s"}}
read_header_timeout: {{ $cfg.read_header_timeout | default "2s" }}
write_timeout: {{ $cfg.write_timeout | default "2s" }}
idle_timeout: {{ $cfg.idle_timeout | default "30s" }}
{{- end }}

{{/*
Renders metrics service configuration.
*/}}
{{- define "aserto-lib.metricsService" -}}
listen_address: 0.0.0.0:{{ include "aserto-lib.metricsPort" . }}
{{- with (include "aserto-lib.mergeGlobal" (list . "metrics") | fromYaml) }}
zpages: {{ .zpages | default "true" }}
{{- if .grpc }}
grpc:
  counters: {{ (.grpc).counters | default "true" }}
  durations: {{ (.grpc).durations | default "true" }}
  gateway: {{ (.grpc).gateway | default "true" }}
{{- end }}
{{- end }}
{{- end }}
