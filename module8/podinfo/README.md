# podinfo Helm chart

Production-ready чарт для [podinfo](https://github.com/stefanprodan/podinfo) с опциональным внутренним Redis.

**Namespace: `podinfo`** (релизы `podinfo` - dev и `podinfo-prod` - prod).

> Платформенный кластер Практикума и GitLab были недоступны, поэтому чарт проверен локально на kind-кластере `kind-practice`.

## Состав
| Ресурс | Условие |
|---|---|
| Deployment, ServiceAccount | всегда / `serviceAccount.create` |
| Service | `service.enabled` (NodePort только при type=NodePort) |
| Ingress (className, TLS) | `ingress.enabled` |
| HPA (CPU + memory) | `hpa.enabled` (при этом `replicas` в Deployment не выводится) |
| PDB | `pdb.enabled` (maxUnavailable приоритетнее minAvailable) |
| Redis: ConfigMap + Deployment (Recreate, checksum/config) + Service `<fullname>-redis` | `redis.enabled`; приложение получает `--cache-server=tcp://<fullname>-redis:6379` |
| Hooks (pre/post install, upgrade, delete, rollback) | `hooks.enabled`, список в `hooks.events` |
| Tests: http, cache (при Redis), fail, timeout | `tests.enabled`, `tests.fail.enabled`, `tests.timeout.enabled` |

## Команды
```bash
helm lint ./podinfo
helm template podinfo ./podinfo
# dev
helm install podinfo ./podinfo -n podinfo --create-namespace --set redis.enabled=true
# upgrade без удаления релиза: отключаем Redis
helm upgrade podinfo ./podinfo -n podinfo --set redis.enabled=false
# prod через override-файл
helm install podinfo-prod ./podinfo -n podinfo -f ./podinfo/values-prod.yaml
helm test podinfo -n podinfo
```
Негативные тесты: `--set tests.fail.enabled=true` (падает), `--set tests.timeout.enabled=true --timeout 20s` (зависает).

## Вывод проверки

```
$ helm list -n podinfo
NAME        	NAMESPACE	REVISION	UPDATED                                	STATUS  	CHART        	APP VERSION
podinfo     	podinfo  	5       	2026-10-25 17:38:08.367020652 +0300 MSK	deployed	podinfo-0.1.0	6.7.1      
podinfo-prod	podinfo  	1       	2026-10-25 17:35:18.627494685 +0300 MSK	deployed	podinfo-0.1.0	6.7.1      

$ helm history podinfo -n podinfo
REVISION	UPDATED                 	STATUS    	CHART        	APP VERSION	DESCRIPTION     
1       	Sun Oct 25 17:34:19 2026	superseded	podinfo-0.1.0	6.7.1      	Install complete
2       	Sun Oct 25 17:35:02 2026	superseded	podinfo-0.1.0	6.7.1      	Upgrade complete
3       	Sun Oct 25 17:36:22 2026	superseded	podinfo-0.1.0	6.7.1      	Upgrade complete
4       	Sun Oct 25 17:36:52 2026	superseded	podinfo-0.1.0	6.7.1      	Upgrade complete
5       	Sun Oct 25 17:38:08 2026	deployed  	podinfo-0.1.0	6.7.1      	Rollback to 2   

$ helm get values podinfo -n podinfo
USER-SUPPLIED VALUES:
hooks:
  enabled: true
redis:
  enabled: false

$ helm get values podinfo-prod -n podinfo
USER-SUPPLIED VALUES:
hpa:
  cpuUtilization: 70
  enabled: true
  maxReplicas: 6
  memoryUtilization: 80
  minReplicas: 3
ingress:
  className: nginx
  enabled: true
  host: podinfo.prod.local
pdb:
  enabled: true
  minAvailable: 2
redis:
  enabled: true
  resources:
    limits:
      memory: 128Mi
    requests:
      cpu: 50m
      memory: 64Mi
replicaCount: 3
resources:
  limits:
    cpu: 500m
    memory: 128Mi
  requests:
    cpu: 100m
    memory: 64Mi

$ kubectl -n podinfo get deploy,hpa,pdb,ing,svc
NAME                                 READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/podinfo              1/1     1            1           4m23s
deployment.apps/podinfo-prod         3/3     3            3           3m39s
deployment.apps/podinfo-prod-redis   1/1     1            1           3m39s

NAME                                               REFERENCE                 TARGETS           MINPODS   MAXPODS   REPLICAS   AGE
horizontalpodautoscaler.autoscaling/podinfo-prod   Deployment/podinfo-prod   1%/70%, 22%/80%   3         6         3          3m39s

NAME                                      MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
poddisruptionbudget.policy/podinfo-prod   2               N/A               1                     3m39s

NAME                                     CLASS   HOSTS                ADDRESS   PORTS   AGE
ingress.networking.k8s.io/podinfo-prod   nginx   podinfo.prod.local             80      3m39s

NAME                         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
service/podinfo              ClusterIP   10.96.173.232   <none>        9898/TCP   4m23s
service/podinfo-prod         ClusterIP   10.96.27.115    <none>        9898/TCP   3m39s
service/podinfo-prod-redis   ClusterIP   10.96.70.158    <none>        6379/TCP   3m39s
```

Сценарий: install (Redis on, hooks on) -> helm test -> upgrade (Redis off, revision 2, ресурсы Redis удалены) -> tests fail/timeout -> rollback на 2 (revision 5) -> prod через -f values-prod.yaml. helm uninstall не использовался.
