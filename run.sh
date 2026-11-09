#!/bin/bash

cd "$(dirname "$0")" || exit 1

PROFILE=shiro-toy

k() { kubectl --context "$PROFILE" "$@"; }

mk() { minikube --profile "$PROFILE" "$@"; }

up() {
  mk start --driver=docker
}

deploy() {
  k apply -k manifests
  k rollout status deployment/hello --timeout=120s
}

test() {
  k -n kube-system wait --for=condition=Ready pod \
    -l k8s-app=kube-dns --timeout=120s ||
    exit 1

  k delete job hello-test --ignore-not-found || exit 1

  k apply -f manifests/test-job.yaml || exit 1

  kubectl --context "$PROFILE" wait job/hello-test \
    --timeout=3m --for=condition=Complete &
  complete_pid=$!
  kubectl --context "$PROFILE" wait job/hello-test \
    --timeout=3m --for=condition=Failed &
  failed_pid=$!

  wait -n "$complete_pid" "$failed_pid"
  kill "$complete_pid" "$failed_pid" 2>/dev/null
  wait 2>/dev/null

  k logs job/hello-test || true

  [ "$(k get job hello-test \
    -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}')" = True ]
}

down() {
  k delete -k manifests --ignore-not-found || true
  mk delete || true
}

case "${1:-}" in
up) up ;;
deploy) deploy ;;
test) test ;;
down) down ;;
*)
  echo "usage: $0 {up|deploy|test|down|pipeline}"
  exit 1
  ;;
esac
