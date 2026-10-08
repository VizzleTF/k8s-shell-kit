# =============================================================================
# k8s-shell-kit: алиасы и функции для kubectl. Подключается из ~/.zshrc:
#   source ~/.config/k8s-shell-kit/k8s.zsh
# =============================================================================

# --- Environment ---------------------------------------------------------------
export KUBE_EDITOR="${KUBE_EDITOR:-nano}"

# compdef нужен ниже; если .zshrc не вызвал compinit, вызываем сами
(( $+functions[compdef] )) || { autoload -Uz compinit && compinit; }

# krew (kubectl plugin manager) в PATH
if [[ -d "${KREW_ROOT:-$HOME/.krew}/bin" ]]; then
    case ":$PATH:" in
        *":${KREW_ROOT:-$HOME/.krew}/bin:"*) ;;
        *) export PATH="$PATH:${KREW_ROOT:-$HOME/.krew}/bin" ;;
    esac
fi

# --- Cached completions (kubectl/helm — генерим раз в неделю в файл) ------------
() {
    setopt localoptions extendedglob
    local cache_dir="$HOME/.cache/zsh"
    [[ -d "$cache_dir" ]] || mkdir -p "$cache_dir"

    _zsh_cache_completion() {
        local name="$1" gen="$2"
        local cache="$HOME/.cache/zsh/$name.zsh"
        # Регенерим если нет файла или он старше 7 дней
        if [[ ! -s "$cache" ]] || [[ -n "$cache"(#qN.m+7) ]]; then
            eval "$gen" > "$cache.tmp" 2>/dev/null && mv "$cache.tmp" "$cache"
        fi
        [[ -s "$cache" ]] && source "$cache"
    }

    command -v kubectl > /dev/null 2>&1 && _zsh_cache_completion kubectl 'kubectl completion zsh'
    command -v helm    > /dev/null 2>&1 && _zsh_cache_completion helm    'helm completion zsh'
    command -v stern   > /dev/null 2>&1 && _zsh_cache_completion stern   'stern --completion zsh'
}

# --- Aliases & functions -------------------------------------------------------
if command -v kubectl > /dev/null 2>&1; then
    # kubecolor colorizes output (yaml/kyaml/json/tables); disables itself when piped
    if command -v kubecolor > /dev/null 2>&1; then
        alias kubectl='kubecolor'
        compdef kubecolor=kubectl
    fi
    # krew resource-capacity: requests/limits рядом с фактом (--util), в %; ktp — текущий ns, -n/-A перебивают
    ktp() { local ns=$(kubectl config view --minify -o jsonpath='{..namespace}'); kubectl resource-capacity --pods --util --sort cpu.util -n "${ns:-default}" "$@" \
        | awk 'NF && !(NR > 2 && $2 == "*" && $3 == "0m")'; }  # без пустых строк и нод без подов
    alias ktn='kubectl resource-capacity --util --pod-count'
    alias k='kubectl'
    alias kg='kubectl get'
    alias kd='kubectl describe'
    alias kdel='kubectl delete'
    alias kgp='kubectl get pods -o wide'
    alias kgpw='kubectl klock pods -o wide'
    alias kgsvc='kubectl get services'
    alias kgsts='kubectl get statefulsets'
    alias kgd='kubectl get deployments'
    alias kgrs='kubectl get replicasets'
    alias kgi='kubectl get ingress'
    alias kgn='kubectl get nodes -o wide'
    alias kgns='kubectl get namespaces'
    alias kgpv='kubectl get pv'
    alias kgpvc='kubectl get pvc'
    alias kgcm='kubectl get configmaps'
    alias kgsec='kubectl get secrets'
    alias kgsa='kubectl get sa'
    alias kgcert='kubectl get certificates'
    alias kgj='kubectl get jobs'
    alias kgcj='kubectl get cronjobs'
    alias kgpp="kubectl get pod -o json | jq '.items[] | {pod: .metadata.name, containers: [.spec.containers[] | select(.ports != null) | {name: .name, ports: .ports}]} | select(.containers | length > 0)'"
    alias kt='stern'
    # kubectl diff → семантический дифф по путям yaml; exit 1 = есть различия
    command -v dyff > /dev/null 2>&1 && export KUBECTL_EXTERNAL_DIFF="dyff --color on between --omit-header --set-exit-code"
    alias kl='kubectl logs'
    alias klf='kubectl logs -f'
    alias kdp='kubectl describe pods'
    alias kdsvc='kubectl describe services'
    alias kdsts='kubectl describe statefulsets'
    alias kdd='kubectl describe deployments'
    alias kdds='kubectl describe replicasets'
    alias kdi='kubectl describe ingress'
    alias kdn='kubectl describe nodes'
    alias kdpv='kubectl describe pv'
    alias kdpvc='kubectl describe pvc'
    alias kdcm='kubectl describe configmaps'
    alias kdcert='kubectl describe certificates'
    alias kdj='kubectl describe jobs'
    alias kdcj='kubectl describe cronjobs'
    alias kns='kubens'
    alias kex='kubectl exec'
    # Регистрирует completion для kubectl-функции: kcompdef <fn> <prefix words...>
    kcompdef() {
        local fn=$1; shift
        local pre="$*" n=$#
        functions[_$fn]="
            words=($pre \"\${(@)words[2,-1]}\")
            (( CURRENT += $n - 1 ))
            _kubectl
        "
        compdef _$fn $fn
    }
    kexi() { local pod=$1; shift; kubectl exec -it "$pod" -- "${@:-bash}"; }
    kcompdef kexi kubectl exec -it
    # kpf <target> [lport] [rport]; target = pod | svc/x | deploy/x (голое имя = pod)
    # без портов — находит родной порт ресурса и форвардит lport=rport на него
    kpf() {
        local target=$1 lport=$2 rport=$3 kind name
        if [[ $target == */* ]]; then kind=${target%%/*}; name=${target#*/}
        else kind=pod; name=$target; fi
        if [[ -z $rport ]]; then
            case $kind in
                svc|service|services)
                    rport=$(kubectl get svc "$name" -o jsonpath='{.spec.ports[0].port}' 2>/dev/null) ;;
                deploy|deployment|deployments)
                    rport=$(kubectl get deploy "$name" -o jsonpath='{.spec.template.spec.containers[0].ports[0].containerPort}' 2>/dev/null) ;;
                *)
                    rport=$(kubectl get pod "$name" -o jsonpath='{.spec.containers[0].ports[0].containerPort}' 2>/dev/null) ;;
            esac
            [[ -z $rport ]] && { print -u2 "kpf: не нашёл порт у $kind/$name — укажи явно"; return 1; }
        fi
        : ${lport:=$rport}
        print "kpf: $target  localhost:$lport → $rport"
        kubectl port-forward "$target" "$lport:$rport"
    }
    kcompdef kpf kubectl port-forward
    # kdsec [secret] [key]; без secret — все секреты namespace; без key — все пары k=v; с key — только значение
    kdsec() {
        if [[ -n "$2" ]]; then
            kubectl get secret "$1" -o go-template="{{index .data \"$2\" | base64decode}}"
        elif [[ -n "$1" ]]; then
            kubectl get secret "$1" -o go-template='{{range $k,$v := .data}}{{$k}}={{$v|base64decode}}{{"\n"}}{{end}}'
        else
            kubectl get secret -o go-template='{{range .items}}{{"=== "}}{{.metadata.name}}{{" ("}}{{.type}}{{")\n"}}{{range $k,$v := .data}}{{$k}}={{$v|base64decode}}{{"\n"}}{{end}}{{"\n"}}{{end}}'
        fi
    }
    kcompdef kdsec kubectl get secret
    alias kdelp='kubectl delete pod'
    alias kdeld='kubectl delete deployment'
    alias kdelrs='kubectl delete replicasets'
    alias kdeli='kubectl delete ingress'
    alias kdelpv='kubectl delete pv'
    alias kdelpvc='kubectl delete pvc'
    alias kdelcm='kubectl delete configmaps'
    alias kdelcert='kubectl delete certificates'
    alias kdelsec='kubectl delete secrets'
    alias kdelns='kubectl delete namespace'
    alias kdelsvc='kubectl delete service'
    alias kdelj='kubectl delete job'
    alias kdelcj='kubectl delete cronjob'
    alias keditj='kubectl edit job'
    alias keditcj='kubectl edit cronjob'
    alias kecm='kubectl edit configmap'
    alias kesec='kubectl edit secret'
    alias ked='kubectl edit deployment'
    alias kei='kubectl edit ingress'
    alias kecert='kubectl edit certificates'
    alias kepv='kubectl edit pv'
    alias kepvc='kubectl edit pvc'
    alias kesvc='kubectl edit service'
    alias kests='kubectl edit statefulset'
    alias kaf='kubectl apply -f'
    # kgy <get args>: yaml без серверного мусора (krew neat), с подсветкой в терминале
    kgy() { kubectl get "$@" -o yaml | kubectl neat | if [[ -t 1 ]]; then yq -C; else cat; fi; }
    kcompdef kgy kubectl get
    # <kg-алиас>y → kgy с тем же ресурсом: kgd → kgdy, kgsvc → kgsvcy; флаги вроде -o wide отбрасываются
    for _a in ${(k)aliases[(I)kg?*]}; do
        _v=$aliases[$_a]
        [[ $_v == 'kubectl get '* && $_v != *'|'* ]] && alias "${_a}y=kgy ${${(z)_v}[3]}"
    done
    unset _a _v
    alias ktree='kubectl tree'
    # fzf-пикеры: kf* [ресурс], превью — describe; kubectx/kubens сами работают через fzf
    _kfzf() {
        kubectl get "${1:-pods}" --no-headers 2>/dev/null \
            | fzf --height=60% --reverse --preview-window=right:60% \
                  --preview "kubecolor --force-colors describe ${1:-pods} {1} 2>/dev/null || kubectl describe ${1:-pods} {1}" \
            | awk '{print $1}'
    }
    kfl() { local p=$(_kfzf pods); [[ -n $p ]] && kubectl logs -f "$p" "$@"; }
    kfe() { local p=$(_kfzf pods); [[ -n $p ]] && kexi "$p" "$@"; }
    kfd() { local r=${1:-pods} n=$(_kfzf ${1:-pods}); [[ -n $n ]] && kubectl describe "$r" "$n"; }
    kfy() { local r=${1:-pods} n=$(_kfzf ${1:-pods}); [[ -n $n ]] && kgy "$r" "$n"; }
fi

