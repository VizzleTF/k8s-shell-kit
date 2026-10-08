#!/usr/bin/env bash
# Installs the k8s-shell-kit tools with Homebrew, the kubectl plugins with krew,
# and hooks k8s.zsh into ~/.zshrc. Safe to re-run.
set -euo pipefail

cd "$(dirname "$0")"

FORMULAE=(
    kubernetes-cli kubecolor kubectx krew stern dyff fzf jq yq
    helm helmfile argocd kubeconform cilium-cli velero talosctl
    int128/kubelogin/kubelogin
)
KREW_PLUGINS=(neat tree resource-capacity klock)
DEST="${XDG_CONFIG_HOME:-$HOME/.config}/k8s-shell-kit"
ZSHRC="${ZDOTDIR:-$HOME}/.zshrc"

if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew not found. Install it first: https://brew.sh" >&2
    exit 1
fi
command -v zsh >/dev/null 2>&1 || echo "warning: zsh not found; k8s.zsh works only in zsh" >&2

echo "==> brew install"
brew install "${FORMULAE[@]}"

echo "==> krew plugins"
kubectl krew update
kubectl krew install "${KREW_PLUGINS[@]}"

echo "==> $DEST/k8s.zsh"
mkdir -p "$DEST"
cp k8s.zsh "$DEST/k8s.zsh"

line="source \"$DEST/k8s.zsh\""
if ! grep -qxF "$line" "$ZSHRC" 2>/dev/null; then
    printf '\n# k8s-shell-kit\n%s\n' "$line" >> "$ZSHRC"
    echo "==> added to $ZSHRC"
fi

echo "Done. Run: exec zsh"
