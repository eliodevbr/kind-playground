#!/usr/bin/env bash

set -e

# CONSTANTS

readonly KIND_NODE_IMAGE=kindest/node:v1.23.3
readonly DNSMASQ_DOMAIN=kind.cluster
readonly DNSMASQ_CONF=kind.k8s.conf

# DETECT OS

detect_os(){
  case "$(uname -s)" in
    Linux*)     declare -g OS=Linux;;
    Darwin*)    declare -g OS=macOS;;
    CYGWIN*|MINGW*|MSYS*) declare -g OS=Windows;;
    *)          declare -g OS=Unknown;;
  esac
  echo "Detected OS: $OS"
}

# FUNCTIONS

log(){
  echo "---------------------------------------------------------------------------------------"
  echo $1
  echo "---------------------------------------------------------------------------------------"
}

wait_ready(){
  local NAME=${1:-pods}
  local TIMEOUT=${2:-5m}
  local SELECTOR=${3:---all}

  log "WAIT $NAME ($TIMEOUT) ..."

  kubectl wait -A --timeout=$TIMEOUT --for=condition=ready $NAME $SELECTOR
}

wait_pods_ready(){
  local TIMEOUT=${1:-5m}

  wait_ready pods $TIMEOUT --field-selector=status.phase!=Succeeded
}

wait_nodes_ready(){
  local TIMEOUT=${1:-5m}

  wait_ready nodes $TIMEOUT
}

network(){
  local NAME=${1:-kind}

  log "NETWORK (kind) ..."

  if [ -z $(docker network ls --filter name=^$NAME$ --format="{{ .Name }}") ]
  then 
    docker network create $NAME
    echo "Network $NAME created"
  else
    echo "Network $NAME already exists, skipping"
  fi
}

proxy(){
  local NAME=$1
  local TARGET=$2

  if [ -z $(docker ps --filter name=^proxy-gcr$ --format="{{ .Names }}") ]
  then
    docker run -d --name $NAME --restart=always --net=kind -e REGISTRY_PROXY_REMOTEURL=$TARGET registry:2
    echo "Proxy $NAME (-> $TARGET) created"
  else
    echo "Proxy $NAME already exists, skipping"
  fi
}

proxies(){
  log "REGISTRY PROXIES ..."

  proxy proxy-docker-hub https://registry-1.docker.io
  proxy proxy-quay       https://quay.io
  proxy proxy-gcr        https://gcr.io
  proxy proxy-k8s-gcr    https://k8s.gcr.io
}

get_service_lb_ip(){
  kubectl get svc -n $1 $2 -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
}

get_subnet(){
  docker network inspect -f '{{(index .IPAM.Config 0).Subnet}}' $1
}

subnet_to_ip(){
  echo $1 | sed "s@0.0/16@$2@"
}

root_ca(){
  log "ROOT CERTIFICATE ..."

  mkdir -p .ssl

  if [[ -f ".ssl/root-ca.pem" && -f ".ssl/root-ca-key.pem" ]]
  then
    echo "Root certificate already exists, skipping"
  else
    openssl genrsa -out .ssl/root-ca-key.pem 2048
    openssl req -x509 -new -nodes -key .ssl/root-ca-key.pem -days 3650 -sha256 -out .ssl/root-ca.pem -subj "/CN=kube-ca"
    echo "Root certificate created"
  fi
}

install_ca(){
  log "INSTALL CERTIFICATE AUTHORITY ..."

  case "$OS" in
    Linux)
      sudo mkdir -p /usr/local/share/ca-certificates/kind.cluster
      sudo cp -f .ssl/root-ca.pem /usr/local/share/ca-certificates/kind.cluster/ca.crt
      sudo update-ca-certificates
      ;;
    macOS)
      sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain .ssl/root-ca.pem 2>/dev/null || echo "Certificate may already be installed"
      ;;
    Windows)
      # For WSL/Git Bash on Windows, try to import to Windows cert store
      if command -v certutil.exe &> /dev/null; then
        certutil.exe -addstore -f "ROOT" .ssl/root-ca.pem 2>/dev/null || echo "Certificate installation may require admin privileges"
      else
        echo "Warning: Certificate installation on Windows requires manual import or running as administrator"
      fi
      ;;
    *)
      echo "Warning: Automatic certificate installation not supported on this OS. Please install .ssl/root-ca.pem manually."
      ;;
  esac
}

cluster(){
  local NAME=${1:-kind}

  log "CLUSTER ..."

  docker pull $KIND_NODE_IMAGE

  # Get absolute path for certificate (cross-platform)
  # This assumes root_ca() has already created the certificate
  local CERT_PATH="$(pwd)/.ssl/root-ca.pem"

  kind create cluster --name $NAME --image $KIND_NODE_IMAGE --config - <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  disableDefaultCNI: true
  kubeProxyMode: none
kubeadmConfigPatches:
  - |-
    kind: ClusterConfiguration
    apiServer:
      extraVolumes:
        - name: opt-ca-certificates
          hostPath: /opt/ca-certificates/root-ca.pem
          mountPath: /opt/ca-certificates/root-ca.pem
          readOnly: true
          pathType: File
      extraArgs:
        oidc-client-id: kube
        oidc-issuer-url: https://keycloak.kind.cluster/auth/realms/master
        oidc-username-claim: email
        oidc-groups-claim: groups
        oidc-ca-file: /opt/ca-certificates/root-ca.pem
    controllerManager:
      extraArgs:
        bind-address: 0.0.0.0
    etcd:
      local:
        extraArgs:
          listen-metrics-urls: http://0.0.0.0:2381
    scheduler:
      extraArgs:
        bind-address: 0.0.0.0
containerdConfigPatches:
  - |-
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
      endpoint = ["http://proxy-docker-hub:5000"]
  - |-
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."quay.io"]
      endpoint = ["http://proxy-quay:5000"]
  - |-
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."k8s.gcr.io"]
      endpoint = ["http://proxy-k8s-gcr:5000"]
  - |-
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."gcr.io"]
      endpoint = ["http://proxy-gcr:5000"]
nodes:
  - role: control-plane
    extraMounts:
      - hostPath: $CERT_PATH
        containerPath: /opt/ca-certificates/root-ca.pem
        readOnly: true
  - role: control-plane
    extraMounts:
      - hostPath: $CERT_PATH
        containerPath: /opt/ca-certificates/root-ca.pem
        readOnly: true
  - role: control-plane
    extraMounts:
      - hostPath: $CERT_PATH
        containerPath: /opt/ca-certificates/root-ca.pem
        readOnly: true
  - role: worker
    extraMounts:
      - hostPath: $CERT_PATH
        containerPath: /opt/ca-certificates/root-ca.pem
        readOnly: true
  - role: worker
    extraMounts:
      - hostPath: $CERT_PATH
        containerPath: /opt/ca-certificates/root-ca.pem
        readOnly: true
  - role: worker
    extraMounts:
      - hostPath: $CERT_PATH
        containerPath: /opt/ca-certificates/root-ca.pem
        readOnly: true
EOF
}

cilium(){
  log "CILIUM ..."

  helm upgrade --install --wait --timeout 15m --atomic --namespace kube-system --create-namespace \
    --repo https://helm.cilium.io cilium cilium --values - <<EOF
kubeProxyReplacement: strict
k8sServiceHost: kind-external-load-balancer
k8sServicePort: 6443
hostServices:
  enabled: true
externalIPs:
  enabled: true
nodePort:
  enabled: true
hostPort:
  enabled: true
image:
  pullPolicy: IfNotPresent
ipam:
  mode: kubernetes
hubble:
  enabled: true
  relay:
    enabled: true
  ui:
    enabled: true
    ingress:
      enabled: true
      annotations:
        kubernetes.io/ingress.class: nginx
        cert-manager.io/cluster-issuer: ca-issuer
      hosts:
        - hubble-ui.$DNSMASQ_DOMAIN
      tls:
        - secretName: hubble-ui.$DNSMASQ_DOMAIN
          hosts:
            - hubble-ui.$DNSMASQ_DOMAIN
EOF
}

cert_manager(){
  log "CERT MANAGER ..."

  helm upgrade --install --wait --timeout 15m --atomic --namespace cert-manager --create-namespace \
    --repo https://charts.jetstack.io cert-manager cert-manager --values - <<EOF
installCRDs: true
EOF
}

cert_manager_ca_secret(){
  kubectl delete secret -n cert-manager root-ca || true
  kubectl create secret tls -n cert-manager root-ca --cert=.ssl/root-ca.pem --key=.ssl/root-ca-key.pem
}

cert_manager_ca_issuer(){
  kubectl apply -n cert-manager -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ca-issuer
spec:
  ca:
    secretName: root-ca
EOF
}

metallb(){
  log "METALLB ..."

  local KIND_SUBNET=$(get_subnet kind)
  local METALLB_START=$(subnet_to_ip $KIND_SUBNET 255.200)
  local METALLB_END=$(subnet_to_ip $KIND_SUBNET 255.250)

  helm upgrade --install --wait --timeout 15m --atomic --namespace metallb-system --create-namespace \
    --repo https://metallb.github.io/metallb metallb metallb --values - <<EOF
configInline:
  address-pools:
    - name: default
      protocol: layer2
      addresses:
        - $METALLB_START-$METALLB_END
EOF
}

ingress(){
  log "INGRESS-NGINX ..."

  helm upgrade --install --wait --timeout 15m --atomic --namespace ingress-nginx --create-namespace \
    --repo https://kubernetes.github.io/ingress-nginx ingress-nginx ingress-nginx --values - <<EOF
defaultBackend:
  enabled: true
EOF
}

dnsmasq(){
  log "DNSMASQ ..."

  local INGRESS_LB_IP=$(get_service_lb_ip ingress-nginx ingress-nginx-controller)

  case "$OS" in
    Linux)
      if command -v systemctl &> /dev/null && systemctl list-unit-files dnsmasq.service &> /dev/null; then
        echo "address=/$DNSMASQ_DOMAIN/$INGRESS_LB_IP" | sudo tee /etc/dnsmasq.d/$DNSMASQ_CONF
      else
        echo "Warning: dnsmasq not found. You may need to manually add DNS entries."
        echo "Add to /etc/hosts: $INGRESS_LB_IP $DNSMASQ_DOMAIN *.$DNSMASQ_DOMAIN"
      fi
      ;;
    macOS)
      if command -v dnsmasq &> /dev/null; then
        # Try different dnsmasq paths on macOS
        local configured=false
        for dnsmasq_path in /usr/local/etc/dnsmasq.d /opt/homebrew/etc/dnsmasq.d; do
          if [ -d "$dnsmasq_path" ]; then
            if echo "address=/$DNSMASQ_DOMAIN/$INGRESS_LB_IP" | sudo tee "$dnsmasq_path/$DNSMASQ_CONF" > /dev/null; then
              configured=true
              break
            fi
          fi
        done
        if [ "$configured" = false ]; then
          echo "Warning: Could not configure dnsmasq. You may need to manually add DNS entries."
        fi
      else
        echo "Warning: dnsmasq not found on macOS. Install with: brew install dnsmasq"
        echo "Or add to /etc/hosts: $INGRESS_LB_IP keycloak.$DNSMASQ_DOMAIN argocd.$DNSMASQ_DOMAIN hubble-ui.$DNSMASQ_DOMAIN"
      fi
      ;;
    Windows)
      echo "Windows detected. Please add the following to C:\Windows\System32\drivers\etc\hosts:"
      echo "$INGRESS_LB_IP keycloak.$DNSMASQ_DOMAIN"
      echo "$INGRESS_LB_IP argocd.$DNSMASQ_DOMAIN"
      echo "$INGRESS_LB_IP hubble-ui.$DNSMASQ_DOMAIN"
      echo "$INGRESS_LB_IP gitea.$DNSMASQ_DOMAIN"
      echo "$INGRESS_LB_IP grafana.$DNSMASQ_DOMAIN"
      echo "$INGRESS_LB_IP prometheus.$DNSMASQ_DOMAIN"
      echo "$INGRESS_LB_IP alertmanager.$DNSMASQ_DOMAIN"
      ;;
    *)
      echo "Warning: DNS configuration not supported on this OS. Please configure DNS manually."
      ;;
  esac
}

restart_service(){
  log "RESTART $1 ..."

  case "$OS" in
    Linux)
      if command -v systemctl &> /dev/null; then
        sudo systemctl restart $1 2>/dev/null || echo "Could not restart $1 service"
      else
        echo "Warning: systemctl not found. Service restart skipped."
      fi
      ;;
    macOS)
      if command -v brew &> /dev/null; then
        brew services restart $1 2>/dev/null || echo "Could not restart $1 service"
      else
        echo "Warning: Could not restart $1 on macOS. You may need to restart it manually."
      fi
      ;;
    Windows)
      echo "Service restart on Windows requires manual action if needed."
      ;;
  esac
}

cleanup(){
  log "CLEANUP ..."

  kind delete cluster || true
  
  case "$OS" in
    Linux)
      sudo rm -f /etc/dnsmasq.d/$DNSMASQ_CONF 2>/dev/null || true
      sudo rm -rf /usr/local/share/ca-certificates/kind.cluster 2>/dev/null || true
      ;;
    macOS)
      sudo rm -f /usr/local/etc/dnsmasq.d/$DNSMASQ_CONF 2>/dev/null || true
      sudo rm -f /opt/homebrew/etc/dnsmasq.d/$DNSMASQ_CONF 2>/dev/null || true
      # Delete certificate by common name (may require manual removal if this fails)
      sudo security delete-certificate -c "kube-ca" /Library/Keychains/System.keychain 2>/dev/null || \
        echo "Note: Certificate removal may require manual action. Check Keychain Access for 'kube-ca'"
      ;;
    Windows)
      echo "Please manually remove certificate and DNS entries if needed."
      ;;
  esac
}

# RUN

detect_os
cleanup
network
proxies
root_ca
install_ca
cluster
cilium
cert_manager
cert_manager_ca_secret
cert_manager_ca_issuer
metallb
ingress
dnsmasq
restart_service   dnsmasq

# DONE

log "CLUSTER READY !"

echo "HUBBLE UI: https://hubble-ui.$DNSMASQ_DOMAIN"
