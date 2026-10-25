{{/* Short chart name */}}
{{- define "podinfo.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Fully qualified resource name: <release>-<chart> (or fullnameOverride) */}}
{{- define "podinfo.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/* Chart name and version for the helm.sh/chart label */}}
{{- define "podinfo.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Selector labels of the application */}}
{{- define "podinfo.selectorLabels" -}}
app.kubernetes.io/name: {{ include "podinfo.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/* Common labels of the application */}}
{{- define "podinfo.labels" -}}
helm.sh/chart: {{ include "podinfo.chart" . }}
{{ include "podinfo.selectorLabels" . }}
app.kubernetes.io/version: {{ .Values.image.tag | default .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/* ServiceAccount name */}}
{{- define "podinfo.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "podinfo.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/* Redis: name = DNS name of the Service */}}
{{- define "podinfo.redis.fullname" -}}
{{- printf "%s-redis" (include "podinfo.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Redis: selector labels (differ from the app so selectors never overlap) */}}
{{- define "podinfo.redis.selectorLabels" -}}
app.kubernetes.io/name: {{ include "podinfo.name" . }}-redis
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/* Redis: common labels */}}
{{- define "podinfo.redis.labels" -}}
helm.sh/chart: {{ include "podinfo.chart" . }}
{{ include "podinfo.redis.selectorLabels" . }}
app.kubernetes.io/component: cache
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/* Labels for hook/test pods: NO selector labels, so Services never route to them */}}
{{- define "podinfo.auxLabels" -}}
helm.sh/chart: {{ include "podinfo.chart" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}
