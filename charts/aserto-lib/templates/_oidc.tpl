{{/*
Returns OICD configuration
*/}}
{{- define "aserto-lib.oidcConfig" -}}
{{- with (include "aserto-lib.mergeGlobal" (list . "oidc")) | fromYaml -}}
domain: "{{ .domain | required ".Values.oidc.domain or .Values.global.aserto.oidc.domain is required" }}"
audience: "{{ .audience | required ".Values.oidc.audience or .Values.global.aserto.oidc.audience is required" }}"
{{- end }}
{{- end }}
