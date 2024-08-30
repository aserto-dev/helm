{{- define "aserto-lib.imagePullSecrets" -}}
{{- with $secrets :=
	.Values.imagePullSecrets |
	default ((.Values.global).aserto).imagePullSecrets |
	default (list (dict "name" "ghcr-creds")) -}}
{{- if $secrets }}
imagePullSecrets:
  {{- toYaml $secrets | nindent 2 }}
{{- end }}
{{- end }}
{{- end }}
