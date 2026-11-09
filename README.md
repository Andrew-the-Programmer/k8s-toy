# k8s-toy

Игрушечный сервис для проверки пайплайна: minikube → образ → манифесты →
smoke-check. Тестов и Argo CD здесь пока нет — это следующие шаги.

## Что внутри

- `app.py` — HTTP-сервис на стандартной библиотеке Python.
- `Dockerfile` — образ сервиса.
- `manifests/` — Deployment на 2 реплики, Service и ConfigMap.
- `run.sh` — шаги пайплайна.

## Запуск

```bash
./run.sh up       # minikube start --driver=docker
./run.sh deploy   # собрать образ внутри minikube, применить манифесты, дождаться rollout
./run.sh check    # запрос через Service
```

Одной командой:

```bash
./run.sh pipeline
```

Остановить и удалить кластер:

```bash
./run.sh down
```

## Что должно получиться

`check` печатает JSON:

```json
{"message": "hello from Kubernetes", "pod": "hello-...", "version": "v1"}
```

`pod` меняется между запросами: Service распределяет их по двум репликам.

## Как устроен пайплайн

`deploy` собирает образ сразу внутрь minikube (`minikube image build`),
поэтому registry и `imagePullSecret` не нужны. Затем `kubectl apply -k`
применяет манифесты, `kubectl rollout restart` пересоздаёт поды (чтобы
подхватить пересобранный образ с тем же тегом), а `kubectl rollout status`
ждёт готовности.

Те же шаги выполняет `.github/workflows/toy.yml` на каждый PR и push в `main`.

## Чего здесь нет

- тестов (следующий шаг);
- Argo CD (после тестов);
- registry и `imagePullSecret`;
- ingress.
