#!/usr/bin/env bash
# Запуск: cd module8 && bash demo.sh   (WSL, контекст kind-practice)
# Весь вывод пишется в demo-output.txt для README. helm uninstall НЕ используется.
set -uo pipefail
NS=podinfo
CH=./podinfo
exec > >(tee demo-output.txt) 2>&1
step(){ echo; echo "########## $*"; }

step "lint + template"
helm lint $CH || exit 1
helm lint $CH -f $CH/values-prod.yaml || exit 1
helm template t $CH >/dev/null && echo "template dev OK"
helm template t $CH -f $CH/values-prod.yaml >/dev/null && echo "template prod OK"

step "metrics-server (нужен для HPA)"
if ! kubectl get deploy metrics-server -n kube-system >/dev/null 2>&1; then
  kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
  kubectl -n kube-system patch deploy metrics-server --type=json \
    -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
fi

step "dev: install (redis включен, хуки включены)"
helm install podinfo $CH -n $NS --create-namespace --set redis.enabled=true --set hooks.enabled=true --wait --timeout 3m
helm list -n $NS
kubectl -n $NS get deploy,svc,cm,po

step "dev: helm test (http + cache)"
helm test podinfo -n $NS

step "dev: upgrade - отключаем Redis (без uninstall)"
helm upgrade podinfo $CH -n $NS --set redis.enabled=false --set hooks.enabled=true --wait --timeout 3m
helm history podinfo -n $NS
kubectl -n $NS get deploy,svc,cm,po
echo "redis ресурсов осталось: $(kubectl -n $NS get deploy,svc,cm -o name | grep -c redis)"
kubectl -n $NS port-forward svc/podinfo 18080:9898 >/dev/null 2>&1 & PF=$!; sleep 3
curl -fsS localhost:18080/healthz; echo; kill $PF

step "negative + timeout тесты (ожидаемо падают)"
helm test podinfo -n $NS --set tests.fail.enabled=true || echo ">>> FAIL-сценарий упал, как и задумано"
helm test podinfo -n $NS --set tests.timeout.enabled=true --timeout 20s || echo ">>> TIMEOUT-сценарий завис, как и задумано"
kubectl -n $NS delete pod -l app.kubernetes.io/component=test --ignore-not-found

step "prod: install через values-prod.yaml"
helm install podinfo-prod $CH -n $NS -f $CH/values-prod.yaml --wait --timeout 4m
kubectl -n $NS get deploy,hpa,pdb,ing,svc
kubectl -n $NS logs deploy/podinfo-prod --tail=5 | head
helm test podinfo-prod -n $NS

step "ИТОГ для README"
helm list -n $NS
echo "--- helm get values podinfo"; helm get values podinfo -n $NS
echo "--- helm get values podinfo-prod"; helm get values podinfo-prod -n $NS
