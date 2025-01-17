{{- define "aserto-lib.controllerClientCfg" }}
{{- include "aserto-lib.mergeGlobal" (list . "controller") }}
{{- end }}

{{- define "aserto-lib.directoryCfg" }}
{{- include "aserto-lib.mergeGlobal" (list . "directory") }}
{{- end }}

{{- define "aserto-lib.discoveryCfg" }}
{{- include "aserto-lib.mergeGlobal" (list . "discovery") }}
{{- end }}

{{- define "aserto-lib.controllerApiKeyEnv" }}
{{- with include "aserto-lib.controllerClientCfg" . | fromYaml -}}
{{- if .apiKey -}}
value: {{ .apiKey }}
{{- else -}}
valueFrom:
  secretKeyRef:
    name: {{ (.apiKeySecret).name | default "controller-key" }}
    key: {{ (.apiKeySecret).key | default "api-key" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "aserto-lib.directoryApiKeys" }}
{{- (include "aserto-lib.directoryCfg" . | fromYaml).apiKeys |
  default (dict "secretName" "directory-keys" "writerKey" "writeKey" "readerKey" "readKey") | toYaml -}}
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
