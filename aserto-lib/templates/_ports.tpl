{{/*
Returns port configuration.
Values are selected with the following precedence:
1. .Values.ports (chart specific overrides)
2. .Values.global.aserto.ports (global overrides)
3. default values ({grpc: 8282, https: 8383, health: 8484, metrics: 8585})
*/}}
{{- define "aserto-lib.ports" }}
{{- $scope := first . }}
{{- $svc := last . }}
{{- $defaults := dict "grpc" 8282 "https" 8383 "health" 8484 "metrics" 8585}}
{{- $global := ($scope.global).aserto | default dict | dig "ports" dict }}
{{- $local := $svc | eq "self" | ternary $scope.ports (dig "global" "aserto" $svc "ports" dict $scope.AsMap) }}
{{- merge $local $global $defaults | toYaml }}
{{- end }}

{{- define "aserto-lib.selfPorts" }}
{{- include "aserto-lib.ports" (list . "self") }}
{{- end }}

{{- define "aserto-lib.grpcPort" }}
{{- (include "aserto-lib.ports" (list . "self") | fromYaml).grpc }}
{{- end }}

{{- define "aserto-lib.httpsPort" }}
{{- (include "aserto-lib.ports" (list . "self") | fromYaml).https }}
{{- end }}

{{- define "aserto-lib.healthPort" }}
{{- (include "aserto-lib.ports" (list . "self") | fromYaml).health }}
{{- end }}

{{- define "aserto-lib.metricsPort" }}
{{- (include "aserto-lib.ports" (list . "self") | fromYaml).metrics }}
{{- end }}

