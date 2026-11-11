#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

K3S_VERSION=v1.37.2+k3s1
ARGOCD_VERSION=v3.6.1

k() { sudo k3s kubectl "$@"; }

init() {
  if ! command -v k3s >/dev/null; then
    # Caddy already owns 80/443 on this machine.
    curl -sfL https://get.k3s.io |
      INSTALL_K3S_VERSION="$K3S_VERSION" \
      INSTALL_K3S_EXEC="server --disable=traefik --disable=servicelb" sh -
  fi
  sudo systemctl enable --now k3s
  k wait --for=condition=Ready node --all --timeout=120s

  k create namespace argocd --dry-run=client -o yaml | k apply -f -
  k apply -n argocd -f \
    "https://raw.githubusercontent.com/argoproj/argo-cd/$ARGOCD_VERSION/manifests/install.yaml"
  k -n argocd rollout status deploy/argocd-server --timeout=300s

  k apply -f argocd/app.yaml

  ip=$(k get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
  token=$(sudo cat /var/lib/rancher/k3s/server/node-token)

  echo "
Argo CD panel:
  sudo k3s kubectl -n argocd port-forward svc/argocd-server 8080:443
  https://localhost:8080  admin
  password: sudo k3s kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d

new server:
  git clone git@github.com:Andrew-the-Programmer/k8s-toy.git
  K3S_URL=https://$ip:6443 K3S_TOKEN=$token ./deploy.sh --profile app"
}

join() {
  profile=$1
  : "${K3S_URL:?set K3S_URL, printed by deploy.sh init on main}"
  : "${K3S_TOKEN:?set K3S_TOKEN, printed by deploy.sh init on main}"

  if ! command -v k3s >/dev/null; then
    curl -sfL https://get.k3s.io |
      K3S_URL="$K3S_URL" K3S_TOKEN="$K3S_TOKEN" \
      INSTALL_K3S_VERSION="$K3S_VERSION" \
      INSTALL_K3S_EXEC="agent --node-label shiro.io/profile=$profile" sh -
  fi
  sudo systemctl enable --now k3s-agent

  echo "joined $K3S_URL as shiro.io/profile=$profile"
}

case "${1:-}" in
init) init ;;
--profile) join "${2:?usage: $0 --profile <name>}" ;;
*)
  echo "usage: $0 init | $0 --profile <name>"
  exit 1
  ;;
esac
