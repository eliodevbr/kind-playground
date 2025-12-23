#!/usr/bin/env bash

# VARIABLES

KUBE_PROMETHEUS_STACK=false
GITOPS=false

# FUNCTIONS

check_bash_version(){
  # Check if bash version is >= 4.2
  # This is required because older versions (like macOS default bash 3.2) 
  # don't support features used by kubectl/helm/kind completion scripts
  if [ -n "$BASH_VERSION" ]; then
    BASH_MAJOR="${BASH_VERSION%%.*}"
    BASH_MINOR="${BASH_VERSION#*.}"
    BASH_MINOR="${BASH_MINOR%%.*}"
    
    if [ "$BASH_MAJOR" -lt 4 ] || ([ "$BASH_MAJOR" -eq 4 ] && [ "$BASH_MINOR" -lt 2 ]); then
      echo "ERROR: Bash version 4.2 or later is required"
      echo "Current version: $BASH_VERSION"
      echo ""
      echo "On macOS, the default bash is version 3.2 which is too old."
      echo "Install a newer bash version using Homebrew:"
      echo "  brew install bash"
      echo ""
      echo "Then run this script using the newer bash:"
      echo "  /usr/local/bin/bash $0"
      exit 1
    fi
  fi
}

log(){
  echo "---------------------------------------------------------------------------------------"
  echo $1
  echo "---------------------------------------------------------------------------------------"
}

verifySupported(){
  if ! type "kubectl" > /dev/null 2>&1; then
    echo "kubectl is required"
    exit 1
  fi

  if ! type "curl" > /dev/null 2>&1; then
    echo "curl is required"
    exit 1
  fi

  if ! type "helm" > /dev/null 2>&1; then
    echo "helm is required"
    exit 1
  fi
}

fail_trap() {
  local RESULT=$?
  log "FAILED WITH RESULT $RESULT !!!"
  exit $RESULT
}

# RUN

trap "fail_trap" EXIT

set -e

set -u

while [[ $# -gt 0 ]]; do
  case $1 in
    '--gitops')
      GITOPS=true
      ;;
    '--kube-prometheus-stack')
      KUBE_PROMETHEUS_STACK=true
      ;;
    *)
      echo "ERROR: Unknown option $1"
      help
      exit 1
      ;;
  esac
  shift
done

set +u

check_bash_version

verifySupported

./cluster.sh
./keycloak.sh
./argocd.sh
./gitea.sh

if [ "$KUBE_PROMETHEUS_STACK" == "true" ]; then
    ./kube-prometheus-stack.sh
fi

if [ "$GITOPS" == "true" ]; then
    ./gitops.sh
else
    ./argocd-applications.sh
fi
