#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/BernardUriza/BernardUriza.git"
INSTALL_DIR="${CLAUDE_PROFILE_DIR:-$HOME/Documents/BernardUriza}"
CLAUDE_DIR="$HOME/.claude"

say() { printf '%s\n' "$*"; }

if [ -d "$INSTALL_DIR/.git" ]; then
  say "→ Repo ya existe en $INSTALL_DIR — git pull --rebase --autostash"
  git -C "$INSTALL_DIR" pull --rebase --autostash
else
  say "→ Clonando $REPO_URL en $INSTALL_DIR"
  git clone "$REPO_URL" "$INSTALL_DIR"
fi

for sub in claude-commands claude-skills; do
  [ -d "$INSTALL_DIR/$sub" ] || { say "ERROR: falta $INSTALL_DIR/$sub — abortando"; exit 1; }
done

mkdir -p "$CLAUDE_DIR"

link() {
  src="$1"; dst="$2"
  if [ -L "$dst" ]; then
    if [ "$(readlink "$dst")" = "$src" ]; then say "✓ $dst ya enlazado"; return; fi
    rm "$dst"
  elif [ -e "$dst" ]; then
    bk="$dst-backup-$(date +%Y%m%d%H%M%S)"
    mv "$dst" "$bk"; say "↳ backup del directorio real: $bk"
  fi
  ln -s "$src" "$dst"; say "✓ $dst -> $src"
}

link "$INSTALL_DIR/claude-commands" "$CLAUDE_DIR/commands"
link "$INSTALL_DIR/claude-skills"   "$CLAUDE_DIR/skills"

n_cmds=$(find -L "$CLAUDE_DIR/commands/" -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')
n_skills=$(find -L "$CLAUDE_DIR/skills/" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')

say ""
say "Instalado: $n_cmds commands, $n_skills skills disponibles globalmente."
say "Actualizar después:  git -C \"$INSTALL_DIR\" pull"
say "Respaldar cambios:   /sync-commands  (dentro de Claude Code)"
