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
{{- with include "aserto-lib.grpcConfig" . | fromYaml }}
connection_timeout_seconds: {{ .connectionTimeoutSec }}
{{- if .certSecret }}
certs:
  tls_key_path: '/grpc-certs/tls.key'
  tls_cert_path: '/grpc-certs/tls.crt'
  tls_ca_cert_path: '/grpc-certs/ca.crt'
{{- end }}
{{- end }}
{{- end }}

{{/*
Renders HTTPS service configuration.
*/}}
{{- define "aserto-lib.httpsService" -}}
listen_address: 0.0.0.0:{{ include "aserto-lib.httpsPort" . }}
{{- with include "aserto-lib.httpsConfig" . | fromYaml }}
{{- with .allowed_origins }}
allowed_origins:
{{- . | toYaml | nindent 2 }}
{{- end }}
read_timeout: {{ .read_timeout | default "2s"}}
read_header_timeout: {{ .read_header_timeout | default "2s" }}
write_timeout: {{ .write_timeout | default "2s" }}
idle_timeout: {{ .idle_timeout | default "30s" }}
{{- with .cerSecret }}
certs:
  tls_key_path: '/https-certs/tls.key'
  tls_cert_path: '/https-certs/tls.crt'
  tls_ca_cert_path: '/https-certs/ca.crt'
{{- end }}
{{- end }}
{{- end }}

{{/*
Renders metrics service configuration.
*/}}
{{- define "aserto-lib.metricsService" -}}
listen_address: 0.0.0.0:{{ include "aserto-lib.metricsPort" . }}
{{- with (include "aserto-lib.mergeGlobal" (list . "metrics") | fromYaml) }}
zpages: {{ .zpages | default "false" }}
{{- if .grpc }}
grpc:
  counters: {{ (.grpc).counters | default "false" }}
  durations: {{ (.grpc).durations | default "false" }}
  gateway: {{ (.grpc).gateway | default "false" }}
{{- end }}
{{- end }}
{{- end }}
