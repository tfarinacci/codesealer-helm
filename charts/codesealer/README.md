# Codesealer Ingress Sidecar Helm Chart

This Helm chart installs [Codesealer](https://codesealer.com) as a sidecar to an
existing ingress deployment. This enabled automatic protection of the application behind
the ingress.

This installation also will configure your Ingress Controller to operate in one the following
2 modes:
   1. NodePort - DEVELOP
      Use for local installations that do not support a LoadBalancer configuration.
      This is the default installation mode.
   2. LoadBalancer - PROD
      used on Production implementations or local configurations that support routing
      to local LoadBalancer over port 443.  Some MacBooks using Docker Desktop with
      Kubernetes support this configuration.

## Prerequisites

To use this Helm chart you will need an access token for the Codesealer Docker registry.
In the following we assume that the access token is set in the following way:

```bash
export CODESEALER_TOKEN=<access token>
```

This installation requires a Kubernetes Cluster with kubectl.  

### Ingress

To use this Helm chart you will also need to set the following variables to match
your Ingress Controller's deployment on your Kubernetes Cluster:

```bash
export INGRESS_HELM_REPO=https://kubernetes.github.io/ingress-nginx
export INGRESS_HELM_CHART=ingress-nginx
export INGRESS_NAMESPACE=ingress-nginx
export INGRESS_DEPLOYMENT=ingress-nginx-controller
export INGRESS_PORT=443
export INGRESS_NODEPORT=31443
export CODESEALER_ENV=DEVELOP
export CODESEALER_CNI=false
```

Additionally you will need an ingress and an application to protect. Below are steps to
get started with a demo application and an Nginx Ingress. For guides on how to use this
Helm chart with specific Kubernetes implementations, see the ["Kubernetes Implementation
Specifics"](#kubernetes-implementation-specifics) section.

This Helm chart will install Codesealer as a sidecar to an existing ingress deployment.

If you don't have an ingress already, you can install an [Nginx Ingress Controller](https://github.com/kubernetes/ingress-nginx/tree/main/charts/ingress-nginx) 
using the following command:

```bash
helm repo add ${INGRESS_HELM_CHART} ${INGRESS_HELM_REPO}
helm install ${INGRESS_HELM_CHART} ${INGRESS_HELM_CHART}/ingress-nginx \
  --namespace ${INGRESS_NAMESPACE} --create-namespace \
  --wait --timeout=90s
```

> NOTE: If using NodePort instead of LoadBalancer, install the Ingress using the following variation
>       specifiying the desired port to use
>
> ```bash
> export INGRESS_NODEPORT=31443
> ```
>
> ```bash
> helm repo add ${INGRESS_HELM_CHART} ${INGRESS_HELM_REPO}
> helm install ${INGRESS_HELM_CHART} ${INGRESS_HELM_CHART}/ingress-nginx \
>   --set controller.hostPort.enabled=true \
>   --set controller.service.type=NodePort \
>   --set controller.service.nodePorts.https=${INGRESS_NODEPORT} \
>   --set controller.updateStrategy.rollingUpdate.maxUnavailable=1 \
>   --wait --timeout=60s
> ```
>
> See also the notes on Kind in the ["Kubernetes Implementation
> Specifics"](#kubernetes-implementation-specifics) section.

### Target Application

Codesealer will add protection to any existing web application. If you don't already
have an application, you can install [OWASP's Juice
Shop](https://owasp.org/www-project-juice-shop/) demo application using the following
command:

```bash
helm repo add securecodebox https://charts.securecodebox.io/
helm install juice-shop securecodebox/juice-shop --namespace juice-shop --create-namespace \
  --set ingress.enabled=true \
  --set "ingress.hosts[0].host=localhost,ingress.hosts[0].paths[0].path=/" \
  --set "ingress.tls[0].hosts[0]=localhost,ingress.tls[0].secretName=" \
  --set ingress.pathType=Prefix \
  --wait --timeout=60s
```

### Redis

To use this Helm chart you will also need to set the following variable to match
your Redis deployment on your Kubernetes Cluster:

```bash
export REDIS_NAMESPACE=redis
```

Codesealer requires Redis. If you don't have your own implementation of Redis you can install 
[Bitnami package for Redis(R)](https://github.com/bitnami/charts/blob/main/bitnami/redis/README.md) 
using the following command:

```bash
helm install redis oci://registry-1.docker.io/bitnamicharts/redis \
  --namespace ${REDIS_NAMESPACE} --create-namespace \
  --set auth.enabled=true \
  --set replica.replicaCount=1 \
  --wait --timeout=60s
```

You will need the Redis generated password to install Codesealer.  You can get that password with
the following command:

```bash
export REDIS_PASSWORD=$(kubectl get secret --namespace ${REDIS_NAMESPACE} redis -o jsonpath="{.data.redis-password}" | base64 -d)
```

## Installing

To install the Codesealer Helm chart, please ensure the prerequisite parametes are defined
and run the following commands:

```bash
helm repo add codesealer https://code-sealer.github.io/helm-charts
helm install codesealer codesealer/codesealer --create-namespace --namespace codesealer-system \
  --set codesealerToken="${CODESEALER_TOKEN}" \
  --set worker.ingress.namespace=${INGRESS_NAMESPACE} \
  --set worker.ingress.deployment=${INGRESS_DEPLOYMENT} \
  --set worker.ingress.port=${INGRESS_PORT} \
  --set worker.redis.namespace=${REDIS_NAMESPACE} \
  --set worker.config.bootloader.redisPassword="${REDIS_PASSWORD}" \
  --wait --timeout=90s
```

To enable Codesealer protection, please ensure the prerequisite parametes are defined
and run the following commands:

```bash
kubectl label ns ${INGRESS_NAMESPACE} codesealer.com/webhook=enabled
kubectl patch deployment ${INGRESS_DEPLOYMENT} -n ${INGRESS_NAMESPACE} -p '{"spec": {"template":{"metadata":{"annotations":{"codesealer.com/injection":"enabled"}}}} }'
```

Finally, restart your ingress deployment if they do not restart automatically:

```bash
kubectl rollout restart deployment/${INGRESS_DEPLOYMENT} --namespace ${INGRESS_NAMESPACE}
kubectl rollout status deployment/${INGRESS_DEPLOYMENT} --namespace ${INGRESS_NAMESPACE} --watch
```

To see what Codesealer helm parameters are available issue the following command:

```bash
helm show values codesealer/codesealer
```

Codesealer has the following default settings which affect Redis and WAF:

  --set worker.redis.service.name=redis-master \
  --set worker.config.bootloader.redisUser=default \
  --set worker.config.bootloader.redisUseTLS=false \
  --set worker.config.bootloader.redisIgnoreTLS=true \
  --set worker.config.endpoint.wafMonitorMode=false \
  --set worker.config.endpoint.enableWaf=true \
  --set worker.config.endpoint.wafFullTransaction=true \
  --set worker.config.endpoint.crs.paranoiaLevel=1 \

> NOTE: If you would like to install Codesealer in `enterprise` mode (with a local Manager) issue the
>       following commands:
>
> ```bash
> helm install codesealer codesealer/codesealer --create-namespace --namespace codesealer-system \
>   --set codesealerToken="${CODESEALER_TOKEN}" \
>   --set worker.ingress.namespace=${INGRESS_NAMESPACE} \
>   --set worker.ingress.deployment=${INGRESS_DEPLOYMENT} \
>   --set worker.ingress.port=${INGRESS_PORT} \
>   --set worker.redis.namespace=${REDIS_NAMESPACE} \
>   --set worker.config.bootloader.redisPassword="${REDIS_PASSWORD}" \
>   --set environment=${CODESEALER_ENV} \
>   --set manager.enabled=true \
>   --wait --timeout=90s
> ```
>
>  NOTE: To access local manager issue the following command:
>
> ```bash
>kubectl port-forward service/core-manager -n ${INGRESS_NAMESPACE} 84444:8444 &
> ```
> You can access the manager at https://localhost:8444
>

## Upgrading

You will need the Redis generated password to upgrade Codesealer.  You can get that password with
the following command:

```bash
export REDIS_PASSWORD=$(kubectl get secret --namespace ${REDIS_NAMESPACE} redis -o jsonpath="{.data.redis-password}" | base64 -d)
```

To upgrade an existing release, please ensure the prerequisite parametes are defined
and run the following command instead:

```bash
helm repo update codesealer
helm upgrade codesealer codesealer/codesealer --namespace codesealer-system \
  --set codesealerToken="${CODESEALER_TOKEN}" \
  --set worker.ingress.namespace=${INGRESS_NAMESPACE} \
  --set worker.ingress.deployment=${INGRESS_DEPLOYMENT} \
  --set worker.ingress.port=${INGRESS_PORT} \
  --set worker.redis.namespace=${REDIS_NAMESPACE} \
  --set worker.config.bootloader.redisPassword="${REDIS_PASSWORD}" \
  --set environment=${CODESEALER_ENV} \
  --wait --timeout=90s
```

Then restart the Codesealer deployment with the following command:

```bash
kubectl rollout restart deployments --namespace codesealer-system
kubectl rollout status deployments --namespace codesealer-system
kubectl rollout restart deployment/${INGRESS_DEPLOYMENT} --namespace ${INGRESS_NAMESPACE}
kubectl rollout status deployment/${INGRESS_DEPLOYMENT} --namespace ${INGRESS_NAMESPACE} --watch
```

> NOTE: If you would like to upgrade Codesealer in `enterprise` mode (with a local Manager) issue the
>       following command instead:
>
> ```bash
> helm upgrade codesealer codesealer/codesealer --namespace codesealer-system \
>   --set codesealerToken="${CODESEALER_TOKEN}" \
>   --set worker.ingress.namespace=${INGRESS_NAMESPACE} \
>   --set worker.ingress.deployment=${INGRESS_DEPLOYMENT} \
>   --set worker.ingress.port=${INGRESS_PORT} \
>   --set worker.redis.namespace=${REDIS_NAMESPACE} \
>   --set worker.config.bootloader.redisPassword="${REDIS_PASSWORD}" \
>   --set environment=${CODESEALER_ENV} \
>   --set manager.enabled=true \
>   --wait --timeout=90s
> ```

## Uninstalling

To uninstall a release,  run the following commands:

```bash
helm uninstall codesealer --namespace codesealer-system
helm repo remove codesealer
```

## Kubernetes Implementation Specifics

### kind

[`kind`](https://kind.sigs.k8s.io/) lets you run Kubernetes on
your local computer. This tool requires that you have either
[Docker](https://www.docker.com/) or [Podman](https://podman.io/) installed.

The kind [Quick Start](https://kind.sigs.k8s.io/docs/user/quick-start/) page
shows you what you need to do to get up and running with kind.

For this chart to work with [Kind](https://kind.sigs.k8s.io/) use the following Kind
configuration:

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
```

<a class="btn btn-primary" href="https://kind.sigs.k8s.io/docs/user/quick-start/" role="button" aria-label="View kind Quick Start Guide">View kind Quick Start Guide</a>