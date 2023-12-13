{{/*
Expand the name of the chart.
*/}}
{{- define "codesealer.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "codesealer.fullname" -}}
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
Create chart name and version as used by the chart label.
*/}}
{{- define "codesealer.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "codesealer.labels" -}}
helm.sh/chart: {{ include "codesealer.chart" . }}
{{ include "codesealer.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "codesealer.selectorLabels" -}}
app.kubernetes.io/name: {{ include "codesealer.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "codesealer.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "codesealer.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Additions
*/}}

{{/*
Create the json for the docker registry credentials
*/}}
{{- define "codesealer.imagePullSecret" -}}
{{- if .Values.imageCredentials }}
{{- if .Values.imageCredentials.password }}
{{- printf "{\"auths\":{\"ghcr.io/code-sealer\":{\"username\":\"code-sealer\",\"password\":\"%s\",\"auth\":\"%s\"}}}" (required ".imageCredentials.password must be passed" .Values.imageCredentials.password) (printf "%s:%s" "code-sealer" .Values.imageCredentials.password | b64enc) | b64enc }}
{{- else }}
{{- printf "{\"auths\":{\"ghcr.io/code-sealer\":{\"username\":\"%s\",\"password\":\"%s\",\"auth\":\"%s\"}}}" "code-sealer" (required ".codesealerToken must be passed" .Values.codesealerToken) (printf "%s:%s" "code-sealer" .Values.codesealerToken | b64enc) | b64enc }}
{{- end }}
{{- else }}
{{- printf "{\"auths\":{\"ghcr.io/code-sealer\":{\"username\":\"%s\",\"password\":\"%s\",\"auth\":\"%s\"}}}" "code-sealer" (required ".codesealerToken must be passed" .Values.codesealerToken) (printf "%s:%s" "code-sealer" .Values.codesealerToken | b64enc) | b64enc }}
{{- end }}
{{- end }}

{{/*
Name of the webhook.
*/}}
{{- define "webhook.name" -}}
{{- default .Values.webhook.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Webhook labels
*/}}
{{- define "webhook.labels" -}}
helm.sh/chart: {{ include "codesealer.chart" . }}
{{ include "webhook.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Webhook Selector labels
*/}}
{{- define "webhook.selectorLabels" -}}
app.kubernetes.io/name: {{ include "webhook.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name for secret to use.
*/}}
{{- define "webhook.secretName" -}}
{{- if .Values.admission.secret.create }}
  {{- default (include "webhook.name" .) .Values.admission.secret.name | trunc 63 | trimSuffix "-" }}
{{- else }}
  {{- default "default" .Values.admission.secret.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the service to use
*/}}
{{- define "webhook.serviceName" -}}
{{- default (include "webhook.name" .) .Values.webhook.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create the name of the admission controller to use
*/}}
{{- define "webhook.admissionName" -}}
{{- default (include "webhook.name" .) .Values.admission.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create service fully qualified hostname
*/}}
{{- define "webhook.service.fullname" -}}
{{- default ( printf "%s.%s.svc" (include "webhook.serviceName" .) .Release.Namespace ) }}
{{- end }}

{{/*
Generate certificate authority
*/}}
{{- define "webhook.gen-certs" -}}
{{- $expiration := (.Values.admission.ca.expiration | int) -}}
{{- if (or (empty .Values.admission.ca.cert) (empty .Values.admission.ca.key)) -}}
{{- $ca :=  genCA "webhook-ca" $expiration -}}
{{- template "webhook.gen-client-tls" (dict "RootScope" . "CA" $ca) -}}
{{- end -}}
{{- end -}}

{{/*
Generate client key and cert from CA
*/}}
{{- define "webhook.gen-client-tls" -}}
{{- $altNames := list ( include "webhook.service.fullname" .RootScope) -}}
{{- $expiration := (.RootScope.Values.admission.ca.expiration | int) -}}
{{- $cert := genSignedCert ( include "codesealer.fullname" .RootScope) nil $altNames $expiration .CA -}}
{{- $clientCert := $cert.Cert | b64enc -}}
{{- $clientKey := $cert.Key | b64enc -}}
caCert: {{ .CA.Cert | b64enc }}
clientCert: {{ $clientCert }}
clientKey: {{ $clientKey }}
{{- end -}}

{{/*
Name of the redis service
*/}}
{{- define "redis.name" -}}
{{- default .Values.redis.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Redis labels
*/}}
{{- define "redis.labels" -}}
helm.sh/chart: {{ include "codesealer.chart" . }}
{{ include "redis.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Redis Selector labels
*/}}
{{- define "redis.selectorLabels" -}}
app.kubernetes.io/name: {{ include "redis.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service to use
*/}}
{{- define "redis.serviceName" -}}
{{- .Values.redis.name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create service fully qualified hostname
*/}}
{{- define "redis.service.fullname" -}}
{{- default ( printf "%s.%s.svc.cluster.local" (include "redis.serviceName" .) .Values.redis.namespace ) }}
{{- end }}

{{/*
Generate Redis certificate authority
*/}}
{{- define "redis.gen-certs" -}}
{{- $redisNamespace := .Values.redis.namespace }}
{{- $clusterDomain := .Values.clusterDomain }}
{{- $fullname := include "codesealer.fullname" . }}
{{- $serviceName := include "redis.serviceName" . }}
{{- $expiration := (.Values.redis.ca.expiration | int) -}}
{{- if (or (empty .Values.redis.ca.cert) (empty .Values.redis.ca.key)) -}}
{{- $ca :=  genCA "redis-ca" $expiration -}}
{{- template "redis.gen-client-tls" (dict "RootScope" . "CA" $ca) -}}
{{- end -}}
{{- end -}}

{{/*
Generate Redis client key and cert from CA
*/}}
{{- define "redis.gen-client-tls" -}}
{{- $redisNamespace := .RootScope.Values.redis.namespace }}
{{- $clusterDomain := .RootScope.Values.clusterDomain }}
{{- $fullname := include "codesealer.fullname" .RootScope }}
{{- $serviceName := include "redis.serviceName" .RootScope }}
{{- $headlessServiceName := printf "%s-headless" $fullname }}
{{- $masterServiceName := printf "%s-master" $fullname }}
{{- $altNames := list (printf "*.%s.%s.svc.%s" $serviceName $redisNamespace $clusterDomain) (printf "%s.%s.svc.%s" $masterServiceName $redisNamespace $clusterDomain) (printf "*.%s.%s.svc.%s" $masterServiceName $redisNamespace $clusterDomain) (printf "*.%s.%s.svc.%s" $headlessServiceName $redisNamespace $clusterDomain) (printf "%s.%s.svc.%s" $headlessServiceName $redisNamespace $clusterDomain) "127.0.0.1" "localhost" $fullname -}}
{{- $expiration := (.RootScope.Values.redis.ca.expiration | int) -}}
{{- $cert := genSignedCert ( include "codesealer.fullname" .RootScope) nil $altNames $expiration .CA -}}
{{- $clientCert := $cert.Cert | b64enc -}}
{{- $clientKey := $cert.Key | b64enc -}}
caCert: {{ .CA.Cert | b64enc }}
clientCert: {{ $clientCert }}
clientKey: {{ $clientKey }}
{{- end -}}

{{/*
Create the name of the service to use
*/}}
{{- define "ingress.serviceName" -}}
{{- range $host := .Values.ingress.hosts }}
{{- $host.host | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Create service fully qualified hostname
*/}}
{{- define "ingress.service.fullname" -}}
{{- default ( printf "%s" (include "ingress.serviceName" .) ) }}
{{- end }}

{{/*
Generate Ingress certificate authority
*/}}
{{- define "ingress.gen-certs" -}}
{{- $expiration := (.Values.ingress.ca.expiration | int) -}}
{{- if (or (empty .Values.ingress.ca.cert) (empty .Values.ingress.ca.key)) -}}
{{- $ca :=  genCA "ingress-ca" $expiration -}}
{{- template "ingress.gen-client-tls" (dict "RootScope" . "CA" $ca) -}}
{{- end -}}
{{- end -}}

{{/*
Generate Ingress client key and cert from CA
*/}}
{{- define "ingress.gen-client-tls" -}}
{{- $altNames := list ( include "ingress.service.fullname" .RootScope) -}}
{{- $expiration := (.RootScope.Values.ingress.ca.expiration | int) -}}
{{- $cert := genSignedCert ( include "codesealer.fullname" .RootScope) nil $altNames $expiration .CA -}}
{{- $clientCert := $cert.Cert | b64enc -}}
{{- $clientKey := $cert.Key | b64enc -}}
caCert: {{ .CA.Cert | b64enc }}
clientCert: {{ $clientCert }}
clientKey: {{ $clientKey }}
{{- end -}}
