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
