{{/*
_helpers.tpl - Reusable template functions for the claude-in-a-box chart.

These named templates generate consistent names, labels, and selectors across
all chart resources. Helm's 63-character limit on label values and resource
names is enforced in each helper via trunc/trimSuffix.
*/}}

{{/*
Chart name truncated to 63 chars.
*/}}
{{- define "claude-in-a-box.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Fully qualified app name.
*/}}
{{- define "claude-in-a-box.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Common labels.
*/}}
{{- define "claude-in-a-box.labels" -}}
app: {{ include "claude-in-a-box.name" . }}
app.kubernetes.io/name: {{ include "claude-in-a-box.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ include "claude-in-a-box.chart" . }}
{{- end }}

{{/*
Selector labels (subset of common labels).
*/}}
{{- define "claude-in-a-box.selectorLabels" -}}
app: {{ include "claude-in-a-box.name" . }}
{{- end }}

{{/*
Chart label value.
*/}}
{{- define "claude-in-a-box.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
ServiceAccount name.
*/}}
{{- define "claude-in-a-box.serviceAccountName" -}}
{{- if .Values.serviceAccount.name }}
{{- .Values.serviceAccount.name }}
{{- else }}
{{- include "claude-in-a-box.fullname" . }}
{{- end }}
{{- end }}
