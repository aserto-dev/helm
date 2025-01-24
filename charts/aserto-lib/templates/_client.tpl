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

{{- define "aserto-lib.controllerClient" -}}
address: {{ include "aserto-lib.controllerAddress" . }}
tenant_id: {{ include "aserto-lib.controllerTenantID" . }}
{{- $cfg := include "aserto-lib.controllerClientCfg" . | fromYaml }}
{{- include "aserto-lib.clientTLS" (mergeOverwrite $cfg (dict "certVolume" "controller-grpc-certs")) -}}
{{- end }}

{{- define "aserto-lib.directoryClient" -}}
address: {{ include "aserto-lib.directoryAddress" . }}
{{- $cfg := include "aserto-lib.mergeGlobal" (list . "directory") | fromYaml }}
{{- include "aserto-lib.clientTLS" (mergeOverwrite $cfg (dict "certVolume" "directory-grpc-certs")) -}}
{{- end }}
