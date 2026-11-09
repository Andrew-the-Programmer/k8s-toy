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

  job_success=$(
    k wait job/hello-test --timeout=3m \
      --for=jsonpath='{.status.conditions[*].status}'=True \
      -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}'
  )
  job_exit_code=$?

  k logs job/hello-test || true

  if [ $job_exit_code -eq 0 ] && [ "${job_success}" = "True" ]; then
    return 0
  else
    return 1
  fi
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
