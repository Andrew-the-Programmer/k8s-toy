#!/bin/sh
# Игрушечный пайплайн: minikube -> образ -> манифесты -> smoke-check.
set -eu
cd "$(dirname "$0")"

PROFILE=shiro-toy
IMAGE=${IMAGE:-shiro-hello:dev}
TEST_IMAGE=${TEST_IMAGE:-ghcr.io/andrew-the-programmer/k8s-toy-tests:tests-v1.0.0}
BUILD=${BUILD:-1}

k() { kubectl --context "$PROFILE" "$@"; }

up() {
  minikube start --profile "$PROFILE" --driver=docker
}

deploy() {
  if [ "$BUILD" = 1 ]; then
    minikube -p "$PROFILE" image build -t "$IMAGE" app
    k apply -k manifests
    k set image deployment/hello hello="$IMAGE"
    k rollout restart deployment/hello
  else
    k apply -k manifests
    k patch deployment hello --type=merge -p \
      "{\"spec\":{\"template\":{\"spec\":{\"imagePullSecrets\":[{\"name\":\"${PULL_SECRET:-ghcr}\"}],\"containers\":[{\"name\":\"hello\",\"image\":\"$IMAGE\"}]}}}}"
  fi
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

test() {
  k -n kube-system wait --for=condition=Ready pod \
    -l k8s-app=kube-dns --timeout=120s

  k delete job hello-test --ignore-not-found

  if [ "$BUILD" = 1 ]; then
    TEST_IMAGE=shiro-hello-test:dev
    minikube -p "$PROFILE" image build -t "$TEST_IMAGE" app-tests
    sed -e '/imagePullSecrets:/,+1d' \
      -e "s|ghcr.io/andrew-the-programmer/k8s-toy-tests:[^ ]*|$TEST_IMAGE|" \
      manifests/test-job.yaml | k apply -f -
  else
    sed "s|ghcr.io/andrew-the-programmer/k8s-toy-tests:[^ ]*|$TEST_IMAGE|" \
      manifests/test-job.yaml | k apply -f -
  fi

  attempt=0
  while [ "$attempt" -lt 36 ]; do
    attempt=$((attempt + 1))
    complete=$(k get job hello-test -o \
      jsonpath='{.status.conditions[?(@.type=="Complete")].status}' \
      2>/dev/null || true)
    failed=$(k get job hello-test -o \
      jsonpath='{.status.conditions[?(@.type=="Failed")].status}' \
      2>/dev/null || true)
    if [ "$complete" = "True" ]; then
      k logs job/hello-test
      return 0
    fi
    if [ "$failed" = "True" ]; then
      k logs job/hello-test || true
      return 1
    fi
    sleep 5
  done

  k logs job/hello-test || true
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
  test) test ;;
  down) down ;;
  pipeline) up && deploy && check && test ;;
  *)
    echo "usage: $0 {up|deploy|check|test|down|pipeline}"
    exit 1
    ;;
esac
