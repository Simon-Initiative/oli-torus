{{- define "oli-torus-preview.prNumber" -}}
{{- printf "%v" (required "Set .Values.prNumber" .Values.prNumber) -}}
{{- end -}}

{{- define "oli-torus-preview.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "oli-torus-preview.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- $pr := include "oli-torus-preview.prNumber" . -}}
{{- printf "%s-%s" $name $pr | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "oli-torus-preview.hostname" -}}
{{- printf "pr-%s.%s" (include "oli-torus-preview.prNumber" .) .Values.previewDomain -}}
{{- end -}}

{{- define "oli-torus-preview.labels" -}}
app.kubernetes.io/name: {{ include "oli-torus-preview.name" . }}
app.kubernetes.io/instance: {{ include "oli-torus-preview.fullname" . }}
app.kubernetes.io/managed-by: Helm
oli.cmu.edu/environment: preview
oli.cmu.edu/pr-number: "{{ include "oli-torus-preview.prNumber" . }}"
{{- end -}}

{{- define "oli-torus-preview.selectorLabels" -}}
app.kubernetes.io/name: {{ include "oli-torus-preview.name" . }}
app.kubernetes.io/instance: {{ include "oli-torus-preview.fullname" . }}
{{- end -}}

{{- define "oli-torus-preview.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (printf "%s-sa" (include "oli-torus-preview.fullname" .)) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "oli-torus-preview.postgresName" -}}
{{- printf "%s-postgres" (include "oli-torus-preview.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "oli-torus-preview.minioName" -}}
{{- printf "%s-minio" (include "oli-torus-preview.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
