{{/*
Expand the name of the chart.
*/}}
{{- define "app-base.name" -}}
{{- .Values.nameOverride | default .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "app-base.fullname" -}}
{{- .Values.nameOverride | default .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Standard Kubernetes recommended labels, plus a custom tier label.
*/}}
{{- define "app-base.labels" -}}
app.kubernetes.io/name: {{ include "app-base.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: {{ include "app-base.name" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
rosetraviss.uk/tier: app
{{- with .Values.labels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "app-base.selectorLabels" -}}
app.kubernetes.io/name: {{ include "app-base.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "app-base.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{ include "app-base.fullname" . }}
{{- else -}}
default
{{- end -}}
{{- end -}}

{{/*
Image reference for the primary container, or an override (used by
extraContainers / cronjobs that don't specify their own image).
*/}}
{{- define "app-base.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}
