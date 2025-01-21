{{- define "aserto-lib.controllerClientCfg" }}
{{- include "aserto-lib.mergeGlobal" (list . "controller") }}
{{- end }}

{{- define "aserto-lib.directoryClientCfg" }}
{{- include "aserto-lib.mergeGlobal" (list . "directory") }}
{{- end }}

{{- define "aserto-lib.discoveryCfg" }}
{{- include "aserto-lib.mergeGlobal" (list . "discovery") }}
{{- end }}


{{- define "aserto-lib.dsApiKeyEnv" -}}
{{- $keyType := index . 1 -}}

{{- with first . -}}
{{- $key := dig "apiKeys" $keyType "" . }}
{{- if $key -}}
value: {{ $key }}
{{- else -}}
valueFrom:
  secretKeyRef:
    name: {{ .apiKeysSecret }}
    key: {{ $keyType }}
{{- end }}
{{- end }}

{{- end }}


{{- define "aserto-lib.controllerReadKeyEnv" -}}
{{- with include "aserto-lib.controllerClientCfg" . | fromYaml | default (dict "apiKeysSecret" "controller-keys") -}}
{{ include "aserto-lib.dsApiKeyEnv" (list . "read") }}
{{- end }}
{{- end }}


{{- define "aserto-lib.controllerWriteKeyEnv" -}}
{{- with include "aserto-lib.controllerClientCfg" . | fromYaml | default (dict "apiKeysSecret" "controller-keys") -}}
{{ include "aserto-lib.dsApiKeyEnv" (list . "write") }}
{{- end }}
{{- end }}


{{- define "aserto-lib.controllerStoreKeyEnv" -}}
{{- with include "aserto-lib.controllerClientCfg" . | fromYaml | default (dict "apiKeysSecret" "controller-keys") -}}
{{ include "aserto-lib.dsApiKeyEnv" (list . "store") }}
{{- end }}
{{- end }}

{{- define "aserto-lib.directoryReadKeyEnv" -}}
{{- with include "aserto-lib.directoryClientCfg" . | fromYaml | default (dict "apiKeysSecret" "directory-keys") -}}
{{ include "aserto-lib.dsApiKeyEnv" (list . "read") }}
{{- end }}
{{- end }}


{{- define "aserto-lib.directoryWriteKeyEnv" -}}
{{- with include "aserto-lib.directoryClientCfg" . | fromYaml | default (dict "apiKeysSecret" "directory-keys") -}}
{{ include "aserto-lib.dsApiKeyEnv" (list . "write") }}
{{- end }}
{{- end }}


{{- define "aserto-lib.directoryStoreKeyEnv" -}}
{{- with include "aserto-lib.directoryClientCfg" . | fromYaml | default (dict "apiKeysSecret" "directory-keys") -}}
{{ include "aserto-lib.dsApiKeyEnv" (list . "store") }}
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
