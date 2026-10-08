# k8s-shell-kit

[English](README.md) · Русский

Алиасы и функции zsh для `kubectl` с цветным выводом, логами нескольких подов, чистым YAML, семантическим `kubectl diff` и выбором ресурсов через fzf. Один скрипт ставит инструменты через Homebrew и подключает конфиг к `~/.zshrc`.

## Установка

Нужны zsh и [Homebrew](https://brew.sh). Проверено на Linux (Ubuntu, WSL2) с zsh 5.9 и kubectl 1.37. Kubeconfig скрипт не трогает.

```sh
git clone https://github.com/VizzleTF/k8s-shell-kit.git
cd k8s-shell-kit
./install.sh
exec zsh
```

`install.sh` делает три вещи, повторный запуск безопасен:

1. `brew install` ставит `kubernetes-cli`, `kubecolor`, `kubectx`, `krew`, `stern`, `dyff`, `fzf`, `jq`, `yq`, `helm`, `helmfile`, `argocd`, `kubeconform`, `cilium-cli`, `velero`, `talosctl`, `int128/kubelogin/kubelogin`.
2. `kubectl krew install` ставит плагины `neat`, `tree`, `resource-capacity`, `klock`.
3. Копирует `k8s.zsh` в `~/.config/k8s-shell-kit/` и дописывает в `~/.zshrc` строку `source ~/.config/k8s-shell-kit/k8s.zsh`.

## Пример

Показать, чем владеет Deployment:

```console
$ ktree deploy coredns -n kube-system
NAMESPACE    NAME                                 READY  REASON  STATUS   AGE
kube-system  Deployment/coredns                   -              -        137d
kube-system  └─ReplicaSet/coredns-f98564579       -              -        32d
kube-system    ├─Pod/coredns-f98564579-lgz8d      True           Current  2d15h
kube-system    └─Pod/coredns-f98564579-tl589      True           Current  2d15h
```

## Удаление

Удалите строку `source …/k8s-shell-kit/k8s.zsh` из `~/.zshrc` и каталог `~/.config/k8s-shell-kit`. Пакеты удаляются через `brew uninstall`, плагины через `kubectl krew uninstall`.

## Шпаргалка

Что действует для всех команд:

- `kubectl` — это алиас на `kubecolor`. Вывод в терминал цветной, при выводе в pipe цвета нет.
- Команды работают в текущем namespace. Флаги `-n <NAMESPACE>` и `-A` дописываются в конец.
- Редактор для `kubectl edit` — `$KUBE_EDITOR`, по умолчанию `nano`.

### Контекст и namespace

| Команда | Действие | Пример |
|---|---|---|
| `kubectx` | Переключает контекст; без аргумента открывает список в fzf | `kubectx` |
| `kns` | Переключает текущий namespace (`kubens`); без аргумента открывает список в fzf | `kns argocd` |

### Списки ресурсов

| Команда | Действие | Пример |
|---|---|---|
| `k`, `kg` | `kubectl`, `kubectl get` | `kg ingress -A` |
| `kgp` | Поды, `-o wide` | `kgp -l app=api` |
| `kgpw` | Поды, `-o wide`, таблица перерисовывается на месте (krew `klock`); выход по `q` | `kgpw -A` |
| `kgn` | Ноды, `-o wide` | `kgn` |
| `kgd`, `kgsvc`, `kgsts`, `kgrs`, `kgi`, `kgns`, `kgpv`, `kgpvc`, `kgcm`, `kgsec`, `kgsa`, `kgcert`, `kgj`, `kgcj` | `kubectl get` для deployments, services, statefulsets, replicasets, ingress, namespaces, pv, pvc, configmaps, secrets, sa, certificates, jobs, cronjobs | `kgd -n argocd` |
| `kgpp` | Порты контейнеров у каждого пода, JSON через `jq` | `kgpp` |
| `ktree` | Дерево владельцев ресурса: Deployment → ReplicaSet → Pod, у каждого Ready и Status (krew `tree`) | `ktree deploy argocd-server -n argocd` |

### YAML ресурса

| Команда | Действие | Пример |
|---|---|---|
| `kgy` | `kubectl get -o yaml` без `status`, `uid`, `resourceVersion`, `creationTimestamp` и прочих полей, которые дописал сервер (krew `neat`). Принимает аргументы `kubectl get` | `kgy deploy argocd-server -n argocd` |
| `kg<X>y` | `kgy` для ресурса алиаса `kg<X>`: `kgdy`, `kgsvcy`, `kgpy`, `kgcmy` и остальные из таблицы выше. Флаги исходного алиаса не переносятся. `kgsecy` выводит `data` секрета в base64 | `kgdy foo > foo.yaml` |
| `kg ... -o kyaml` | Полный ресурс в формате KYAML с подсветкой | `kgd foo -o kyaml` |
| `kdsec` | Расшифровывает секреты: без аргументов все в namespace, с именем все пары `ключ=значение`, с именем и ключом одно значение | `kdsec db-creds password` |

### Describe, логи, exec, port-forward

| Команда | Действие | Пример |
|---|---|---|
| `kd`, `kdp`, `kdd`, `kdsvc`, `kdsts`, `kdds`, `kdi`, `kdn`, `kdpv`, `kdpvc`, `kdcm`, `kdcert`, `kdj`, `kdcj` | `kubectl describe` для ресурса; `kdds` — replicasets | `kdp api-7d9f-x2k` |
| `kl`, `klf` | `kubectl logs`, `kubectl logs -f` для одного пода | `klf deploy/api` |
| `kt` | `stern`: логи всех подов, имя которых совпадает с regex. Подхватывает поды, созданные после запуска. По умолчанию показывает логи за последние 48 часов, `--since` меняет окно | `kt api -n prod --include error --since 1h` |
| `kex` | `kubectl exec` | `kex api-7d9f-x2k -- env` |
| `kexi` | `kubectl exec -it`; без команды запускает `bash` | `kexi api-7d9f-x2k sh` |
| `kpf` | Port-forward на под, `svc/<NAME>` или `deploy/<NAME>`. Без портов берёт первый порт ресурса и открывает его на том же локальном порту | `kpf svc/grafana 3000` |

### Изменение и удаление

| Команда | Действие | Пример |
|---|---|---|
| `kaf` | `kubectl apply -f` | `kaf foo.yaml` |
| `kubectl diff` | Показывает, что изменит `apply`: изменённые пути YAML со старым и новым значением (`dyff`). Код возврата 0 без различий, 1 при различиях | `kubectl diff -f foo.yaml` |
| `ked`, `kesvc`, `kests`, `kei`, `kecm`, `kesec`, `kecert`, `kepv`, `kepvc`, `keditj`, `keditcj` | `kubectl edit` для deployment, service, statefulset, ingress, configmap, secret, certificates, pv, pvc, job, cronjob | `ked api` |
| `kdel`, `kdelp`, `kdeld`, `kdelrs`, `kdelsvc`, `kdeli`, `kdelcm`, `kdelsec`, `kdelcert`, `kdelpv`, `kdelpvc`, `kdelj`, `kdelcj`, `kdelns` | `kubectl delete` для ресурса; удаляет без подтверждения | `kdelp api-7d9f-x2k` |

### Нагрузка

| Команда | Действие | Пример |
|---|---|---|
| `ktn` | По каждой ноде: CPU и память в requests, limits и фактическом потреблении, в единицах и процентах, плюс число подов (krew `resource-capacity`) | `ktn` |
| `ktp` | То же по подам текущего namespace, сортировка по потреблению CPU. Ноды без подов из namespace не выводятся | `ktp -A --sort mem.util` |

`ktn` и `ktp` показывают фактическое потребление, только если в кластере стоит metrics-server.

### Выбор через fzf

Список ресурсов текущего namespace открывается в fzf, справа показан `describe` выбранного.

| Команда | Действие после выбора | Пример |
|---|---|---|
| `kfl` | `kubectl logs -f` пода; аргументы уходят в `logs` | `kfl --tail 100` |
| `kfe` | `kexi` в под; аргумент задаёт команду | `kfe sh` |
| `kfd` | `kubectl describe` ресурса; по умолчанию `pods` | `kfd svc` |
| `kfy` | `kgy` ресурса; по умолчанию `pods` | `kfy deploy` |

### Отдельные инструменты

| Инструмент | Назначение | Пример |
|---|---|---|
| `helm` | Чарты и релизы | `helm list -A` |
| `helmfile` | Набор helm-релизов из одного файла | `helmfile diff` |
| `argocd` | CLI Argo CD | `argocd app list` |
| `kubeconform` | Проверяет манифесты по схемам | `kubeconform -strict foo.yaml` |
| `dyff` | Сравнивает два YAML по путям | `dyff between old.yaml new.yaml` |
| `cilium` | Состояние Cilium в кластере | `cilium status` |
| `velero` | Бэкапы кластера | `velero backup get` |
| `talosctl` | Управление нодами Talos | `talosctl -n <NODE_IP> health` |
| `kubelogin` | OIDC-логин; kubectl вызывает его сам из kubeconfig | — |
| `kubectl krew` | Плагины kubectl | `kubectl krew upgrade` |
