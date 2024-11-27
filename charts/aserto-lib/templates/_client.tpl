{{- define "aserto-lib.clientTLS" }}
{{- if .noVerify | and .noTLS -}}
  {{- fail "'noVerify' and 'noTLS' are mutually exclusive." }}
{{- end }}
{{- if .noTLS }}
no_tls: true
{{- else if .skipVerify }}
insecure : true
{{- else if .caCertSecret }}
ca_cert_path: /{{ .certVolume }}/ca.crt
{{- end }}
{{- end }}

{{- define "aserto-lib.rootDirectoryClient" -}}
address: {{ include "aserto-lib.rootDirectoryAddress" . }}
tenant_id: {{ include "aserto-lib.rootDirectoryTenantID" . }}
{{- $cfg := include "aserto-lib.rootClientCfg" . | fromYaml }}
{{- include "aserto-lib.clientTLS" (mergeOverwrite $cfg (dict "certVolume" "root-ds-grpc-certs")) -}}
{{- end }}

{{- define "aserto-lib.directoryClient" -}}
address: {{ include "aserto-lib.directoryAddress" . }}
{{- $cfg := include "aserto-lib.mergeGlobal" (list . "directory") | fromYaml }}
{{- include "aserto-lib.clientTLS" (mergeOverwrite $cfg (dict "certVolume" "ds-grpc-certs")) -}}
{{- end }}
