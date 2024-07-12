{{/*
Returns the cluster address of a given service.
Args: [scope, config, service]
- scope: the chart scope
- config: the name of the config section to retrieve. This is used to merge
  global values with local values. For example if config is "foo", this
  function will return .Values.foo merged with .Values.global.aserto.foo.
- service: the name of the service to retrieve the address for (e.g. "directory").
*/}}
{{- define "aserto-lib.svcClusterAddress" }}
{{- $scope := first . }}
{{- $portType := index . 1 }}
{{- $cfg := index . 2 }}
{{- $svc := last . }}
{{- $addr := (include "aserto-lib.mergeGlobal" (list $scope $cfg) | fromYaml).address }}
{{- if $addr }}
{{- tpl $addr $scope }}
{{- else }}
{{- $port := include "aserto-lib.ports" (list $scope $cfg) | fromYaml | dig $portType ""  | toYaml }}
{{- printf "%s-%s.%s.svc.cluster.local:%s" $scope.Release.Name $svc $scope.Release.Namespace $port }}
{{- end }}
{{- end }}

{{/*
Cluster address of the root directory service
*/}}
{{- define "aserto-lib.rootDirectoryAddress" }}
{{- include "aserto-lib.svcClusterAddress" (list . "grpc" "rootDirectory" "directory")}}
{{- end }}

{{/*
Cluster address of the directory service
*/}}
{{- define "aserto-lib.directoryAddress" }}
{{- include "aserto-lib.svcClusterAddress" (list . "grpc" "directory" )}}
{{- end }}

{{/*
Cluster address of the discovery service
*/}}
{{- define "aserto-lib.discoveryAddress" }}
{{- include "aserto-lib.svcClusterAddress" (list . "https" "discovery" )}}
{{- end }}

