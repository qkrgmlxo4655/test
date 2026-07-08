{{/* 릴리스명-컴포넌트명 형태의 리소스 이름 */}}
{{- define "runway-app.fullname" -}}
{{- printf "%s-%s" .Release.Name .component | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* 공통 라벨 */}}
{{- define "runway-app.labels" -}}
app.kubernetes.io/name: {{ .component }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end -}}

{{/* selector 라벨 */}}
{{- define "runway-app.selectorLabels" -}}
app.kubernetes.io/name: {{ .component }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
