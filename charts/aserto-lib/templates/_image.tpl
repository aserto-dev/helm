{{- define "aserto-lib.imagePullSecrets" -}}
{{- with $secrets := .Values.imagePullSecrets | default ((.Values.global).aserto).imagePullSecrets | default list }}
{{- if $secrets }}
imagePullSecrets:
  {{- toYaml $secrets | nindent 2 }}
{{- end }}
{{- end }}
{{- end }}
