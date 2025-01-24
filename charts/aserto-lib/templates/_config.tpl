{{- define "aserto-lib.controllerClientCfg" }}
{{- include "aserto-lib.mergeGlobal" (list . "controller") | fromYaml |
	merge (dict "apiKeysSecret" "controller-keys") | toYaml }}
{{- end }}

{{- define "aserto-lib.directoryClientCfg" }}
{{- include "aserto-lib.mergeGlobal" (list . "directory") | fromYaml |
	merge (dict "apiKeysSecret" "directory-keys") | toYaml }}
{{- end }}

{{- define "aserto-lib.discoveryCfg" }}
{{- include "aserto-lib.mergeGlobal" (list . "discovery") }}
{{- end }}


{{- define "aserto-lib.dsApiKeyEnv" -}}
{{- $keyType := index . 1 -}}
{{- $defaultSecretName := index . 2 -}}

{{- with first . -}}
{{- $key := dig "apiKeys" $keyType "" . }}
{{- if $key -}}
value: {{ $key }}
{{- else -}}
valueFrom:
  secretKeyRef:
    name: {{ .apiKeysSecret | default $defaultSecretName }}
    key: {{ $keyType }}
{{- end }}
{{- end }}

{{- end }}


{{- define "aserto-lib.controllerKeyEnv" -}}
{{- $scope := first . -}}
{{- $keyType := last . -}}
{{- with include "aserto-lib.controllerClientCfg" $scope | fromYaml -}}
{{ include "aserto-lib.dsApiKeyEnv" (list . $keyType "controller-keys") }}
{{- end }}
{{- end }}


{{- define "aserto-lib.directoryKeyEnv" -}}
{{- $scope := first . -}}
{{- $keyType := last . -}}
{{- with include "aserto-lib.directoryClientCfg" $scope | fromYaml -}}
{{ include "aserto-lib.dsApiKeyEnv" (list . $keyType "directory-keys") }}
{{- end }}
{{- end }}


{{- define "aserto-lib.discoveryApiKey" }}
{{- (include "aserto-lib.discoveryCfg" . | fromYaml).apiKey |
  default (dict "secretName" "discovery-keys" "secretKey" "api-key") | toYaml -}}
{{- end }}


{{/*
Root directory tenant ID
*/}}
{{- define "aserto-lib.controllerTenantID" -}}
{{- (include "aserto-lib.controllerClientCfg" . | fromYaml).tenantID |
	default "00000000-0000-11ef-0000-000000000000" -}}
{{- end }}

{{/*
Takes a k8s resource retrieved using the `lookup` function and returns true
if the resource is managed by the current helm release. False otherwise.
*/}}
{{- define "aserto-lib.isManagedResource" -}}
{{- $resource := first . | default dict }}
{{- $releaseName := last . }}
{{- if $resource | dig "metadata" "labels" "app.kubernetes.io/managed-by" "" | eq "Helm" | and
       ($resource | dig "metadata" "annotations" "meta.helm.sh/release-name" "" | eq $releaseName) -}}
true
{{- else -}}
false
{{- end }}
{{- end }}
