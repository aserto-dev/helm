{{- define "aserto-lib.imagePullSecrets" -}}
{{- with $secrets := .Values.imagePullSecrets | default .Values.global.aserto.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml $secrets | nindent 2 }}
{{- end }}
{{- end }}
