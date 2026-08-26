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

{{/*
Labels that identify the *serving* pods, and only those.

CronJob pods carry app-base.labels too, which contains name and instance, so
they match app-base.selectorLabels exactly. A Service selecting on those alone
therefore lists every running CronJob pod as an endpoint -- Ready, because a
job pod has no readiness probe -- and sends a share of HTTP traffic to a
container with nothing listening on the port.

Measured on worldbody 2026-08-26: 5 of 12 connections to the ClusterIP were
refused while one estate job was running. ingress-nginx retries the next
upstream on a refused connection, so it does not surface as a 5xx to users; it
surfaces as latency and as confusing 502s during rollouts, which is why it
survived this long.

The Deployment's own spec.selector deliberately does NOT gain this label:
selectors are immutable, and adding it there would make every existing release
fail to upgrade. Only the Service needs to be narrowed, and the Deployment's
ReplicaSet already avoids adopting job pods via its pod-template-hash.
*/}}
{{- define "app-base.webSelectorLabels" -}}
{{ include "app-base.selectorLabels" . }}
app.kubernetes.io/component: web
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
