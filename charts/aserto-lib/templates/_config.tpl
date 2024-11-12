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
	default "06e1fdac-0676-11ef-b77e-0005a79d9368" -}}
{{- end }}
