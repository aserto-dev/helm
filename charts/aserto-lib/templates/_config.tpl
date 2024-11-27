{{- define "aserto-lib.rootClientCfg" }}
{{- include "aserto-lib.mergeGlobal" (list . "rootDS") }}
{{- end }}

{{- define "aserto-lib.directoryCfg" }}
{{- include "aserto-lib.mergeGlobal" (list . "directory") }}
{{- end }}

{{- define "aserto-lib.discoveryCfg" }}
{{- include "aserto-lib.mergeGlobal" (list . "discovery") }}
{{- end }}

{{- define "aserto-lib.rootApiKeyEnv" }}
{{- with include "aserto-lib.rootClientCfg" . | fromYaml -}}
{{- if .apiKey -}}
value: {{ .apiKey }}
{{- else -}}
valueFrom:
  secretKeyRef:
    name: {{ (.apiKeySecret).name | default "root-ds-keys" }}
    key: {{ (.apiKeySecret).key | default "api-key" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "aserto-lib.directoryApiKeys" }}
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
{{- (include "aserto-lib.rootClientCfg" . | fromYaml).tenantID |
	default "00000000-0000-11ef-0000-000000000000" -}}
{{- end }}
