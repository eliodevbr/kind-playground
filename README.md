# kind-playground

This repository contains code, scripts and manifests i use to play with local
Kubernetes clusters with Kind, Cilium, MetalLB, Keycloak, ArgoCD and various
other tools.

## Platform Compatibility

These scripts are compatible with **Linux**, **macOS**, and **Windows** (via WSL, Git Bash, or similar subsystems).

### Requirements

- Docker
- kubectl
- helm
- kind
- jq
- openssl
- terraform (for Keycloak configuration)

### Platform-Specific Notes

#### Linux
- Certificate installation requires `sudo` privileges
- DNS configuration uses `dnsmasq` (if available) or instructions for `/etc/hosts`

#### macOS  
- Certificate installation uses `security` command and requires `sudo` privileges
- DNS configuration uses `dnsmasq` (if installed via Homebrew) or instructions for `/etc/hosts`

#### Windows (WSL/Git Bash)
- Certificate installation may require manual import or administrator privileges
- DNS configuration requires manual modification of the `hosts` file
- The scripts will provide instructions for manual configuration steps

## Basic cluster

The [cluster.sh](./cluster.sh) script will bootstrap a local cluster with Kind and configure it
to use Cilium CNI (without `kube-proxy`), MetalLB, ingress-nginx and dnsmasq.

The cluster api server will be configured to use Keycloak identity provider.

It will also setup docker image caching through proxies for docker.io, quay.io,
gcr.io and k8s.gcr.io.

Run `./cluster.sh` to create a local cluster.

## Keycloak

The [keycloak.sh](./keycloak.sh) script contains code to deploy Keycloak in a running cluster.

In addition to deploying Keycloak, it will also configure it using terraform
to be ready to use with ArgoCD and other applications for SSO authentication.

Keycloak will be available through HTTPS, using a certificate that is trusted by the cluster
api server.

Run `./keycloak.sh` to deploy and configure Keycloak.

## ArgoCD

The [argocd.sh](./argocd.sh) script contains code to deploy ArgoCD in a running cluster.

ArgoCD will be configured to use Keycloak OIDC endpoint and SSO authentication.

Run `./argocd.sh` to deploy ArgoCD.

## ArgoCD applications

The [argocd](./argocd) folder contains code ArgoCD application manifests.

Run `kubectl -n argocd -f ./argocd/<application name>` to deploy an application.

Available applications:
- [argocd](./argocd/argocd.yaml)
- [cert-manager](./argocd/cert-manager.yaml)
- [cilium](./argocd/cilium.yaml)
- [gitea](./argocd/gitea.yaml)
- [ingress-nginx](./argocd/ingress-nginx.yaml)
- [keycloak](./argocd/keycloak.yaml)
- [kube-prometheus-stack](./argocd/kube-prometheus-stack.yaml)
- [kubeview](./argocd/kubeview.yaml)
- [kyverno](./argocd/kyverno.yaml)
- [kyverno-policies](./argocd/kyverno-policies.yaml)
- [mattermost-team-edition](./argocd/mattermost-team-edition.yaml)
- [metrics-server](./argocd/metrics-server.yaml)
- [minio](./argocd/minio.yaml)
- [node-problem-detector](./argocd/node-problem-detector.yaml)
- [polaris](./argocd/polaris.yaml)
- [policy-reporter](./argocd/policy-reporter.yaml)
- [rbac-manager](./argocd/rbac-manager.yaml)
