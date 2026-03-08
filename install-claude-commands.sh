#!/bin/bash
# ============================================================
# Claude Code Commands — Global Installer
# ============================================================
# Syncs claude-commands/ from this repo to ~/.claude/commands/
# Run this once per machine. Pull this repo to update commands.
#
# Usage:
#   git clone https://github.com/BernardUriza/BernardUriza.git
#   cd BernardUriza
#   chmod +x install-claude-commands.sh
#   ./install-claude-commands.sh
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE="$SCRIPT_DIR/claude-commands"
TARGET="$HOME/.claude/commands"

echo "🔧 Claude Code Commands — Global Installer"
echo "   Source: $SOURCE"
echo "   Target: $TARGET"
echo ""

# Validate source exists
if [ ! -d "$SOURCE" ]; then
    echo "❌ No se encontró $SOURCE"
    echo "   Asegúrate de correr esto desde la raíz del repo BernardUriza."
    exit 1
fi

# Handle existing target
if [ -L "$TARGET" ]; then
    CURRENT=$(readlink "$TARGET")
    if [ "$CURRENT" = "$SOURCE" ]; then
        echo "✅ Ya está linkeado correctamente."
        echo "   $TARGET → $SOURCE"
        echo ""
        echo "📋 Commands disponibles:"
        ls "$SOURCE"/*.md 2>/dev/null | xargs -I{} basename {} .md | sed 's/^/   \//'
        exit 0
    fi
    echo "⚠️  Symlink existente apunta a: $CURRENT"
    echo "   Reemplazando con: $SOURCE"
    rm "$TARGET"
elif [ -d "$TARGET" ]; then
    # Back up existing commands that aren't in source
    BACKUP="$HOME/.claude/commands-backup-$(date +%Y%m%d-%H%M%S)"
    echo "📦 Respaldando commands existentes en: $BACKUP"
    mv "$TARGET" "$BACKUP"
    echo "   (Si no los necesitas, borra $BACKUP después)"
fi

# Ensure parent directory exists
mkdir -p "$(dirname "$TARGET")"

# Create symlink
ln -s "$SOURCE" "$TARGET"

echo "✅ Instalado!"
echo "   $TARGET → $SOURCE"
echo ""
echo "📋 Commands disponibles globalmente:"
ls "$SOURCE"/*.md 2>/dev/null | xargs -I{} basename {} .md | sed 's/^/   \//'
echo ""
echo "🔄 Para actualizar commands en el futuro:"
echo "   cd $(dirname "$SCRIPT_DIR")/BernardUriza && git pull"
echo ""
echo "💡 Los commands de proyecto (.claude/commands/ en cada repo)"
echo "   siguen funcionando y tienen prioridad sobre los globales."
