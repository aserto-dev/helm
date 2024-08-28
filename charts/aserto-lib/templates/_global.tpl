{{/*
Returns a config section merged with its global counterpart.
Input is a list with the first element being the chart scope (e.g. .) and
the second element being the name of the config section to retrieve.

For example, if the input is [., "foo"], this function will return
.Values.foo merged with .Values.global.aserto.foo.

Local values take precedence over global values.
*/}}
{{- define "aserto-lib.mergeGlobal" }}
{{- $scope := first . }}
{{- $key := index . 1}}
{{- $global := (($scope.Values).global).aserto | default dict | dig $key dict }}
{{- $chart := $scope.Values.AsMap | dig  $key dict }}
{{- merge $chart $global | toYaml }}
{{- end }}
