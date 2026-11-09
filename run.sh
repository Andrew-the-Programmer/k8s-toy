#!/bin/sh
# Игрушечный пайплайн: minikube -> образ -> манифесты -> smoke-check.
set -eu
cd "$(dirname "$0")"

PROFILE=shiro-toy
IMAGE=shiro-hello:dev

k() { kubectl --context "$PROFILE" "$@"; }

up() {
  minikube start --profile "$PROFILE" --driver=docker
}

deploy() {
  minikube -p "$PROFILE" image build -t "$IMAGE" .
  k apply -k manifests
  k rollout restart deployment/hello
  k rollout status deployment/hello --timeout=120s
}

check() {
  k run hello-check --rm -i --restart=Never \
    --image=busybox:1.36 -- \
    wget -qO- http://hello/
}

down() {
  k delete -k manifests --ignore-not-found
  minikube delete --profile "$PROFILE" || true
}

case "${1:-}" in
  up) up ;;
  deploy) deploy ;;
  check) check ;;
  down) down ;;
  pipeline) up && deploy && check ;;
  *)
    echo "usage: $0 {up|deploy|check|down|pipeline}"
    exit 1
    ;;
esac
