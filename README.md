# k8s-shell-kit

English · [Русский](README.ru.md)

zsh aliases and functions for `kubectl`: colored output, logs from many pods at once, YAML without server-set fields, a per-path `kubectl diff`, and fzf pickers. One script installs the tools with Homebrew and hooks the config into `~/.zshrc`.

## Install

You need zsh and [Homebrew](https://brew.sh). Tested on Linux (Ubuntu, WSL2) with zsh 5.9 and kubectl 1.37. The script leaves your kubeconfig alone.

```sh
git clone https://github.com/VizzleTF/k8s-shell-kit.git
cd k8s-shell-kit
./install.sh
exec zsh
```

`install.sh` does three things and is safe to re-run:

1. `brew install` installs `kubernetes-cli`, `kubecolor`, `kubectx`, `krew`, `stern`, `dyff`, `fzf`, `jq`, `yq`, `helm`, `helmfile`, `argocd`, `kubeconform`, `cilium-cli`, `velero`, `talosctl` and `int128/kubelogin/kubelogin`.
2. `kubectl krew install` installs the plugins `neat`, `tree`, `resource-capacity` and `klock`.
3. It copies `k8s.zsh` to `~/.config/k8s-shell-kit/` and appends `source ~/.config/k8s-shell-kit/k8s.zsh` to `~/.zshrc`.

## Example

Show what a Deployment owns:

```console
$ ktree deploy coredns -n kube-system
NAMESPACE    NAME                                 READY  REASON  STATUS   AGE
kube-system  Deployment/coredns                   -              -        137d
kube-system  └─ReplicaSet/coredns-f98564579       -              -        32d
kube-system    ├─Pod/coredns-f98564579-lgz8d      True           Current  2d15h
kube-system    └─Pod/coredns-f98564579-tl589      True           Current  2d15h
```

## Uninstall

Remove the `source …/k8s-shell-kit/k8s.zsh` line from `~/.zshrc` and delete `~/.config/k8s-shell-kit`. Remove packages with `brew uninstall` and plugins with `kubectl krew uninstall`.

## Command reference

These apply to every command:

- `kubectl` is an alias for `kubecolor`. Output to a terminal is colored; output to a pipe is plain.
- Commands run in the current namespace. Append `-n <NAMESPACE>` or `-A`.
- `kubectl edit` opens `$KUBE_EDITOR`, `nano` when unset.

### Context and namespace

| Command | Action | Example |
|---|---|---|
| `kubectx` | Switches context; with no argument, opens the list in fzf | `kubectx` |
| `kns` | Switches the current namespace (`kubens`); with no argument, opens the list in fzf | `kns argocd` |

### Listing resources

| Command | Action | Example |
|---|---|---|
| `k`, `kg` | `kubectl`, `kubectl get` | `kg ingress -A` |
| `kgp` | Pods, `-o wide` | `kgp -l app=api` |
| `kgpw` | Pods, `-o wide`, table redrawn in place (krew `klock`); quit with `q` | `kgpw -A` |
| `kgn` | Nodes, `-o wide` | `kgn` |
| `kgd`, `kgsvc`, `kgsts`, `kgrs`, `kgi`, `kgns`, `kgpv`, `kgpvc`, `kgcm`, `kgsec`, `kgsa`, `kgcert`, `kgj`, `kgcj` | `kubectl get` for deployments, services, statefulsets, replicasets, ingress, namespaces, pv, pvc, configmaps, secrets, sa, certificates, jobs, cronjobs | `kgd -n argocd` |
| `kgpp` | Container ports of each pod, JSON through `jq` | `kgpp` |
| `ktree` | Ownership tree of a resource: Deployment → ReplicaSet → Pod, with Ready and Status for each (krew `tree`) | `ktree deploy argocd-server -n argocd` |

### Resource YAML

| Command | Action | Example |
|---|---|---|
| `kgy` | `kubectl get -o yaml` without `status`, `uid`, `resourceVersion`, `creationTimestamp` and other fields the server sets (krew `neat`). Takes `kubectl get` arguments | `kgy deploy argocd-server -n argocd` |
| `kg<X>y` | `kgy` for the resource of alias `kg<X>`: `kgdy`, `kgsvcy`, `kgpy`, `kgcmy` and the rest from the table above. Flags of the source alias are dropped. `kgsecy` prints the secret `data` in base64 | `kgdy foo > foo.yaml` |
| `kg ... -o kyaml` | The full resource as KYAML, colored | `kgd foo -o kyaml` |
| `kdsec` | Decodes secrets: with no arguments, every secret in the namespace; with a name, all `key=value` pairs; with a name and a key, one value | `kdsec db-creds password` |

### Describe, logs, exec, port-forward

| Command | Action | Example |
|---|---|---|
| `kd`, `kdp`, `kdd`, `kdsvc`, `kdsts`, `kdds`, `kdi`, `kdn`, `kdpv`, `kdpvc`, `kdcm`, `kdcert`, `kdj`, `kdcj` | `kubectl describe` for the resource; `kdds` is replicasets | `kdp api-7d9f-x2k` |
| `kl`, `klf` | `kubectl logs`, `kubectl logs -f` for one pod | `klf deploy/api` |
| `kt` | `stern`: logs of every pod whose name matches a regex. Picks up pods created after start. Shows the last 48 hours by default; `--since` changes the window | `kt api -n prod --include error --since 1h` |
| `kex` | `kubectl exec` | `kex api-7d9f-x2k -- env` |
| `kexi` | `kubectl exec -it`; runs `bash` when no command is given | `kexi api-7d9f-x2k sh` |
| `kpf` | Port-forward to a pod, `svc/<NAME>` or `deploy/<NAME>`. With no ports, takes the first port of the resource and opens it on the same local port | `kpf svc/grafana 3000` |

### Changing and deleting

| Command | Action | Example |
|---|---|---|
| `kaf` | `kubectl apply -f` | `kaf foo.yaml` |
| `kubectl diff` | Shows what `apply` would change: each changed YAML path with its old and new value (`dyff`). Exits 0 with no differences, 1 with differences | `kubectl diff -f foo.yaml` |
| `ked`, `kesvc`, `kests`, `kei`, `kecm`, `kesec`, `kecert`, `kepv`, `kepvc`, `keditj`, `keditcj` | `kubectl edit` for deployment, service, statefulset, ingress, configmap, secret, certificates, pv, pvc, job, cronjob | `ked api` |
| `kdel`, `kdelp`, `kdeld`, `kdelrs`, `kdelsvc`, `kdeli`, `kdelcm`, `kdelsec`, `kdelcert`, `kdelpv`, `kdelpvc`, `kdelj`, `kdelcj`, `kdelns` | `kubectl delete` for the resource; deletes without confirmation | `kdelp api-7d9f-x2k` |

### Resource usage

| Command | Action | Example |
|---|---|---|
| `ktn` | Per node: CPU and memory requests, limits and actual usage, in units and percent, plus pod count (krew `resource-capacity`) | `ktn` |
| `ktp` | The same per pod in the current namespace, sorted by CPU usage. Nodes with no pods from the namespace are hidden | `ktp -A --sort mem.util` |

`ktn` and `ktp` show actual usage only when metrics-server runs in the cluster.

### fzf pickers

Each picker opens the resources of the current namespace in fzf, with `describe` of the selected one on the right.

| Command | Action after selection | Example |
|---|---|---|
| `kfl` | `kubectl logs -f` of the pod; arguments go to `logs` | `kfl --tail 100` |
| `kfe` | `kexi` into the pod; an argument sets the command | `kfe sh` |
| `kfd` | `kubectl describe` of the resource; `pods` by default | `kfd svc` |
| `kfy` | `kgy` of the resource; `pods` by default | `kfy deploy` |

### Standalone tools

| Tool | Purpose | Example |
|---|---|---|
| `helm` | Charts and releases | `helm list -A` |
| `helmfile` | A set of helm releases from one file | `helmfile diff` |
| `argocd` | Argo CD CLI | `argocd app list` |
| `kubeconform` | Validates manifests against schemas | `kubeconform -strict foo.yaml` |
| `dyff` | Compares two YAML files by path | `dyff between old.yaml new.yaml` |
| `cilium` | Cilium status in the cluster | `cilium status` |
| `velero` | Cluster backups | `velero backup get` |
| `talosctl` | Talos node management | `talosctl -n <NODE_IP> health` |
| `kubelogin` | OIDC login; kubectl calls it from the kubeconfig | — |
| `kubectl krew` | kubectl plugins | `kubectl krew upgrade` |
