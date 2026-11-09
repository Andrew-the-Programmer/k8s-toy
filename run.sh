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
  k -n kube-system wait --for=condition=Ready pod \
    -l k8s-app=kube-dns --timeout=120s

  attempt=0
  while [ "$attempt" -lt 5 ]; do
    attempt=$((attempt + 1))
    if timeout 60 kubectl --context "$PROFILE" run "hello-check-$attempt" \
      --rm -i --restart=Never --image=busybox:1.36 -- \
      wget -T 5 -t 1 -qO- http://hello/; then
      return 0
    fi
    sleep 5
  done
  return 1
}

down() {
  k delete -k manifests --ignore-not-found || true
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
