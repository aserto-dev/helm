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
{{- (include "aserto-lib.rootDirectoryCfg" . | fromYaml).tenantID |
	required ".Values.rootDirectory.tenantID or .Values.global.aserto.rootDirectory.tenantID must be set" -}}
{{- end }}
