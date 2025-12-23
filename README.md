# kind-playground

This repository contains code, scripts and manifests i use to play with local
Kubernetes clusters with Kind, Cilium, MetalLB, Keycloak, ArgoCD and various
other tools.

## Requirements

- **Bash 4.2 or later** - The scripts require bash version 4.2 or later. On macOS, the default bash is version 3.2 which is too old. Install a newer version using Homebrew:
  ```bash
  brew install bash
  ```
  Then run scripts using the newer bash:
  ```bash
  /usr/local/bin/bash ./_bootstrap.sh
  ```
  Alternatively, you can change your default shell or add `/usr/local/bin/bash` to `/etc/shells` and use `chsh`.

- **kubectl** - Kubernetes command-line tool
- **helm** - Kubernetes package manager
- **docker** - Container runtime
- **kind** - Kubernetes in Docker
- **curl** - For making HTTP requests
- **terraform** - For Keycloak configuration (optional, only needed for keycloak.sh)

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
