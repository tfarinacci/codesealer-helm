#!/bin/sh

##+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+
##
##  Usage: ./test_install.sh [install | uninstall | upgrade]
##
##+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+#+

clear

# Github login
echo $CODESEALER_PAT | docker login ghcr.io -u USERNAME --password-stdin

# Public Helm Repo
export CODESEALER_REPO=tfarinacci/codesealer-helm/main/
# CODESEALER_REPO=code-sealer/helm-charts/main/

export INGRESS_NAMESPACE=ingress-nginx
export INGRESS_DEPLOYMENT=ingress-nginx-controller

if [[ "$1" == "install" ]]; then

  echo "\n########################################################################################"
  echo "#  Do you wish to install NGINX Ingress Controller to access the OWASP Juice Shop Application?"
  echo "########################################################################################"
  read -p 'Install NGINX Ingress Controller [y/n]: '
  if [ $REPLY == 'y' ]; then
    helm upgrade --install ingress-nginx ingress-nginx \
    --repo https://kubernetes.github.io/ingress-nginx \
    --namespace $INGRESS_NAMESPACE --create-namespace
  else
    echo "\n########################################################################################"
    echo "#  Skipping NGINX Ingress Controller installation"
    echo "########################################################################################"
  fi

  echo "\n########################################################################################"
  echo "#  Install OWASP Juice Shop Application"
  echo "########################################################################################"
  read -s -t 20 -p '?Press any key to continue.'

  helm repo add securecodebox https://charts.securecodebox.io/
  helm install juice-shop securecodebox/juice-shop --namespace juice-shop --create-namespace \
    --set ingress.enabled=true \
    --set "ingress.hosts[0].host=localhost,ingress.hosts[0].paths[0].path=/" \
    --set "ingress.tls[0].hosts[0]=localhost,ingress.tls[0].secretName=" \
    --set ingress.pathType=Prefix

  echo "\n########################################################################################"
  echo "#  Install Codesealer"
  echo "########################################################################################"
  read -s -t 10 -p '?Press any key to continue.'
  # Install Codesealer helm repo
  helm repo add codesealer https://raw.githubusercontent.com/${CODESEALER_REPO}
  # Install Codsealer
  helm install codesealer-1 codesealer/codesealer --create-namespace --namespace codesealer-system \
    --set worker.ingress.namespace=${INGRESS_NAMESPACE} \
    --set worker.config.waf.wafMonitorMode=false \
    --set worker.config.waf.enableWaf=true \
    --set worker.config.waf.wafFullTransaction=true \
    --set worker.config.waf.paranoiaLevel=1     

    # --set worker.ingress.hostname=localhost \
    # --set worker.ingress.hostScheme=https \
    # --set workers.ingress.appNamespace=juice-shop \
    # --set redis.namespace=codesealer-system \
    # --set ingress.namespace=codesealer-system \
    # --set ingress.enabled=true \
    # --set "ingress.tls[0].hosts[0]=core-manager.local,ingress.tls[0].secretName=core-manager-tls" \
    # --set "ingress.hosts[0].host=core-manager.local,ingress.hosts[0].paths[0].path=/,ingress.hosts[0].paths[0].pathType=Prefix"

  echo "\n########################################################################################"
  echo "#  Waiting 30 seconds for Codesealer to install"
  echo "########################################################################################"
  sleep 30

  echo "\n########################################################################################"
  echo "#  Activate Codesealer by applying labels and annotations"
  echo "########################################################################################"
  read -s -p '?Press any key to continue.'

  # Enable Codesealer
  echo "\n########################################################################################"
  echo "  $ kubectl label ns $INGRESS_NAMESPACE codesealer.com/webhook=enabled"
  echo "\n"
  kubectl label ns $INGRESS_NAMESPACE codesealer.com/webhook=enabled

  echo "\n"
  echo "  $ kubectl patch deployment $INGRESS_DEPLOYMENT -n $INGRESS_NAMESPACE -p '{"spec": {"template":{"metadata":{"annotations":{"codesealer.com/injection":"enabled"}}}} }'"
  kubectl patch deployment $INGRESS_DEPLOYMENT -n $INGRESS_NAMESPACE -p '{"spec": {"template":{"metadata":{"annotations":{"codesealer.com/injection":"enabled"}}}} }'
  echo "\n########################################################################################"
  
elif [[ "$1" == "uninstall" ]]; then

  echo "\n########################################################################################"
  echo "#  Uninstall Codesealer"
  echo "########################################################################################"
  helm uninstall codesealer-1 --namespace codesealer-system
  helm repo remove codesealer

  echo "\n########################################################################################"
  echo "#  Uninstall OWASP Juice Shop Application"
  echo "########################################################################################"
  helm uninstall juice-shop --namespace juice-shop
  helm repo remove securecodebox

  echo "\n########################################################################################"
  echo "#  Do you wish to uninstall NGINX Ingress Controller?"
  echo "########################################################################################"
  read -p 'Uninstall NGINX Ingress Controller [y/n]: '
  if [ $REPLY == 'y' ]; then
    helm uninstall ingress-nginx --namespace $INGRESS_NAMESPACE
  else
    echo "\n########################################################################################"
    echo "#  Skipping NGINX Ingress Controller uninstall"
    echo "########################################################################################"
  fi

elif [[ "$1" == "upgrade" ]]; then

  echo "\n########################################################################################"
  echo "#  Upgrade Codesealer Release"
  echo "########################################################################################"
  helm repo update codesealer
  helm upgrade codesealer-1 codesealer/codesealer --namespace codesealer-system \
    --set worker.ingress.namespace=${INGRESS_NAMESPACE} \
    --set worker.config.waf.wafMonitorMode=false \
    --set worker.config.waf.enableWaf=true \
    --set worker.config.waf.wafFullTransaction=true \
    --set worker.config.waf.paranoiaLevel=1

  echo "\n########################################################################################"
  echo "#  Upgrade Codesealer"
  echo "########################################################################################"
  read -s -t 30 -p '?Press any key to continue.'
  kubectl rollout restart deployments --namespace codesealer-system

  echo "\n########################################################################################"
  echo "#  Please wait 1 minute..."
  echo "########################################################################################"
  sleep 60

  echo "\n########################################################################################"
  echo "#  Upgrade Codesealer Worker Sidecar for NGINX Ingress Controller"
  echo "########################################################################################"
  read -s -t 30 -p '?Press any key to continue.'
  # kubectl rollout restart deployments --namespace $INGRESS_NAMESPACE
  kubectl scale deployment $INGRESS_DEPLOYMENT  --namespace $INGRESS_NAMESPACE --replicas=0
  sleep 20   
  kubectl scale deployment $INGRESS_DEPLOYMENT  --namespace $INGRESS_NAMESPACE --replicas=1

else

  echo "\n########################################################################################"
  echo "#  Invalid arguement: must install, upgrade, or uninstall"
  echo "########################################################################################"

fi

