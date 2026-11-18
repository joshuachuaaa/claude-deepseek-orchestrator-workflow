#!/bin/sh
# Installs the engineering-orchestrator workflow:
#   - the skill and its subagents into Claude Code
#   - the DeepSeek worker's agent into OpenCode (GPT-6.2 Sol runs through the
#     Codex CLI and needs no agent file)
#   - `delegate` onto your PATH
# A file that already exists and differs is left alone unless you pass --force.
# Runs on Linux and macOS, and on Windows from Git Bash.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
claude=${CLAUDE_CONFIG_DIR:-$HOME/.claude}
opencode=${XDG_CONFIG_HOME:-$HOME/.config}/opencode
bin=${DELEGATE_BIN_DIR:-$HOME/.local/bin}
force=no
[ "${1:-}" = "--force" ] && force=yes

put() { # put <source> <destination>
    if [ -e "$2" ] && ! cmp -s "$1" "$2" && [ "$force" = no ]; then
        echo "kept       $2 (it differs; pass --force to replace it)"
        return 0
    fi
    if [ -e "$2" ] && cmp -s "$1" "$2"; then
        echo "unchanged  $2"
        return 0
    fi
    mkdir -p "$(dirname "$2")"
    cp -p "$1" "$2"
    echo "installed  $2"
}

skill=skills/engineering-orchestrator
put "$here/$skill/SKILL.md"              "$claude/$skill/SKILL.md"
put "$here/$skill/scripts/delegate"      "$claude/$skill/scripts/delegate"
put "$here/$skill/templates/dossier.md"  "$claude/$skill/templates/dossier.md"
for agent in fable-architect fable-signoff test-runner; do
    put "$here/agents/$agent.md" "$claude/agents/$agent.md"
done
put "$here/opencode/agents/eng-implementer.md" "$opencode/agents/eng-implementer.md"

target=$claude/$skill/scripts/delegate
chmod +x "$target"
mkdir -p "$bin"

case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) windows=yes ;;
    *) windows=no ;;
esac

if [ "$windows" = yes ]; then
    # Git Bash has no real symlinks and usually no `python3`, so `delegate` is a
    # small launcher that runs the installed script with a Python that works.
    py=
    for cand in python3 python; do
        if command -v "$cand" >/dev/null 2>&1 && "$cand" -c "import sys" >/dev/null 2>&1; then
            py=$cand
            break
        fi
    done
    if [ -z "$py" ]; then
        echo "error: no working python3 or python on PATH" >&2
        exit 1
    fi
    launcher=$(mktemp)
    printf '#!/bin/sh\n# Written by install.sh: runs the installed delegate script.\nexec %s "%s" "$@"\n' \
        "$py" "$target" > "$launcher"
    chmod +x "$launcher"
    put "$launcher" "$bin/delegate"
    rm -f "$launcher"
elif [ -e "$bin/delegate" ] || [ -L "$bin/delegate" ]; then
    if [ "$force" = no ] && [ "$(readlink "$bin/delegate" 2>/dev/null || true)" != "$target" ]; then
        echo "kept       $bin/delegate (already there; pass --force to point it here)"
    else
        ln -sfn "$target" "$bin/delegate"
        echo "linked     $bin/delegate -> $target"
    fi
else
    ln -s "$target" "$bin/delegate"
    echo "linked     $bin/delegate -> $target"
fi

echo
echo "Next: make sure $bin is on your PATH, sign in with 'codex login', then run 'delegate check' inside a git repository."
