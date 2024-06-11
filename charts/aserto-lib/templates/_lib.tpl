{{/*
Returns port configuration.
Values are selected with the following precedence:
1. .Values.ports (chart specific overrides)
2. .Values.global.aserto.ports (global overrides)
3. default values ({grpc: 8282, https: 8383, health: 8484, metrics: 8585})
*/}}
{{- define "aserto-lib.ports" }}
{{- $scope := first . }}
{{- $svc := last . }}
{{- $defaults := dict "grpc" 8282 "https" 8383 "health" 8484 "metrics" 8585}}
{{- $global := ($scope.global).aserto | default dict | dig "ports" dict }}
{{- $local := $svc | eq "self" | ternary $scope.ports (dig "global" "aserto" $svc "ports" dict $scope.AsMap) }}
{{- merge $local $global $defaults | toYaml }}
{{- end }}

{{- define "aserto-lib.selfPorts" }}
{{- include "aserto-lib.ports" (list . "self") }}
{{- end }}

{{- define "aserto-lib.grpcPort" }}
{{- (include "aserto-lib.ports" (list . "self") | fromYaml).grpc }}
{{- end }}

{{- define "aserto-lib.httpsPort" }}
{{- (include "aserto-lib.ports" (list . "self") | fromYaml).https }}
{{- end }}

{{- define "aserto-lib.healthPort" }}
{{- (include "aserto-lib.ports" (list . "self") | fromYaml).health }}
{{- end }}

{{- define "aserto-lib.metricsPort" }}
{{- (include "aserto-lib.ports" (list . "self") | fromYaml).metrics }}
{{- end }}

{{/*
Returns a config section merged with its global counterpart.
Input is a list with the first element being the chart scope (e.g. .) and
the second element being the name of the config section to retrieve.

For example, if the input is [., "foo"], this function will return
.Values.foo merged with .Values.global.aserto.foo.

Local values take precedence over global values.
*/}}
{{- define "aserto-lib.mergeGlobal" }}
{{- $scope := first . }}
{{- $key := index . 1}}
{{- $global := (($scope.Values).global).aserto | default dict | dig $key dict }}
{{- $chart := $scope.Values.AsMap | dig  $key dict }}
{{- merge $chart $global | toYaml}}
{{- end }}

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
Returns OICD configuration
*/}}
{{- define "aserto-lib.oidcConfig" -}}
{{- with (include "aserto-lib.mergeGlobal" (list . "oidc")) | fromYaml -}}
domain: "{{ .domain | required ".Values.oidc.domain or .Values.global.aserto.oidc.domain is required" }}"
audience: "{{ .audience | required ".Values.oidc.audience or .Values.global.aserto.oidc.audience is required" }}"
{{- end }}
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
{{- with (include "aserto-lib.httpsConfig" . | fromYaml) }}
allowed_origins: {{ .allowed_origins | default list }}
read_timeout: {{ .read_timeout | default "2s"}}
read_header_timeout: {{ .read_header_timeout | default "2s" }}
write_timeout: {{ .write_timeout | default "2s" }}
idle_timeout: {{ .idle_timeout | default "30s" }}
{{- end }}
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

{{/*
Returns the cluster address of a given service.
Args: [scope, config, service]
- scope: the chart scope
- config: the name of the config section to retrieve. This is used to merge
  global values with local values. For example if config is "foo", this
  function will return .Values.foo merged with .Values.global.aserto.foo.
- service: the name of the service to retrieve the address for (e.g. "directory").
*/}}
{{- define "aserto-lib.svcClusterAddress" }}
{{- $scope := first . }}
{{- $portType := index . 1 }}
{{- $cfg := index . 2 }}
{{- $svc := last . }}
{{- $addr := (include "aserto-lib.mergeGlobal" (list $scope $cfg) | fromYaml).address }}
{{- if $addr }}
{{- tpl $addr $scope }}
{{- else }}
{{- $port := include "aserto-lib.ports" (list $scope $cfg) | fromYaml | dig $portType ""  | toYaml }}
{{- printf "%s-%s.%s.svc.cluster.local:%s" $scope.Release.Name $svc $scope.Release.Namespace $port }}
{{- end }}
{{- end }}

{{/*
Cluster address of the root directory service
*/}}
{{- define "aserto-lib.rootDirectoryAddress" }}
{{- include "aserto-lib.svcClusterAddress" (list . "grpc" "rootDirectory" "directory")}}
{{- end }}

{{/*
Cluster address of the directory service
*/}}
{{- define "aserto-lib.directoryAddress" }}
{{- include "aserto-lib.svcClusterAddress" (list . "grpc" "directory" )}}
{{- end }}

{{/*
Cluster address of the discovery service
*/}}
{{- define "aserto-lib.discoveryAddress" }}
{{- include "aserto-lib.svcClusterAddress" (list . "https" "discovery" )}}
{{- end }}

{{- define "aserto-lib.rootDirectoryCfg" }}
{{- include "aserto-lib.mergeGlobal" (list . "rootDirectory") }}
{{- end }}

{{- define "aserto-lib.directoryCfg" }}
{{- include "aserto-lib.mergeGlobal" (list . "directory") }}
{{- end }}

{{- define "aserto-lib.discoveryCfg" }}
{{- include "aserto-lib.mergeGlobal" (list . "discovery") }}
{{- end }}

{{- define "aserto-lib.rootDirectoryApiKey" }}
{{- (include "aserto-lib.rootDirectoryCfg" . | fromYaml).apiKey |
  default (dict "secretName" "root-ds-keys" "secretKey" "api-key") | toYaml -}}
{{- end }}

{{- define "aserto-lib.directoryApiKey" }}
{{- (include "aserto-lib.directoryCfg" . | fromYaml).apiKey |
  default (dict "secretName" "ds-keys" "writerSecretKey" "writeKey" "readerSecretKey" "readKey") | toYaml -}}
{{- end }}

{{- define "aserto-lib.discoveryApiKey" }}
{{- (include "aserto-lib.discoveryCfg" . | fromYaml).apiKey |
  default (dict "secretName" "discovery-keys" "secretKey" "api-key") | toYaml -}}
{{- end }}


{{/*
Root directory tenant ID
*/}}
{{- define "aserto-lib.rootDirectoryTenantID" -}}
{{- (include "aserto-lib.rootDirectoryCfg" . | fromYaml).tenantID |
	required ".Values.rootDirectory.tenantID or .Values.global.aserto.rootDirectory.tenantID must be set" -}}
{{- end }}

{{- define "aserto-lib.clientCA" }}
{{- if .disableTLSVerification }}
insecure : true
{{- else if .grpcCertSecret }}
ca_cert_path: /{{ .certVolume }}/ca.crt
{{- else }}
ca_cert_path: /grpc-certs/ca.crt
{{- end }}
{{- end }}

{{- define "aserto-lib.rootDirectoryClient" -}}
address: {{ include "aserto-lib.rootDirectoryAddress" . }}
tenant_id: {{ include "aserto-lib.rootDirectoryTenantID" . }}
{{- $cfg := include "aserto-lib.rootDirectoryCfg" . | fromYaml }}
{{- include "aserto-lib.clientCA" (mergeOverwrite $cfg (dict "certVolume" "root-ds-grpc-certs")) -}}
{{- end }}

{{- define "aserto-lib.directoryClient" -}}
address: {{ include "aserto-lib.directoryAddress" . }}
{{- $cfg := include "aserto-lib.mergeGlobal" (list . "directory") | fromYaml }}
{{- include "aserto-lib.clientCA" (mergeOverwrite $cfg (dict "certVolume" "ds-grpc-certs")) -}}
{{- end }}
