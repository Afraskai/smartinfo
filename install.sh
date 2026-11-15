#!/usr/bin/env bash
# Installer fuer smartinfo
#
#   ./install.sh                  # nach ~/.local/bin (ohne Root)
#   ./install.sh --system         # nach /usr/local/bin (mit sudo)
#   ./install.sh --prefix /opt    # eigenes Ziel
#   ./install.sh --uninstall      # entfernen
#
# Funktioniert auch ohne lokale Dateien:
#   curl -fsSL https://raw.githubusercontent.com/Afraskai/smartinfo/main/install.sh | bash

set -euo pipefail

VERSION="1.0.0"
RAW_BASE="${SMARTINFO_RAW_BASE:-https://raw.githubusercontent.com/Afraskai/smartinfo/main}"

PREFIX="${PREFIX:-$HOME/.local}"
BINDIR="${BINDIR:-$PREFIX/bin}"
MODE="install"
USE_SUDO=0

case ${SMARTINFO_LANG:-${LC_ALL:-${LANG:-}}} in
    de*) L=de ;;
    *)   L=en ;;
esac

msg() {
    case $L in
        de)
            case $1 in
                title)       echo "smartinfo $VERSION - Installation" ;;
                target)      echo "Ziel" ;;
                copy)        echo "Kopiere smartinfo nach" ;;
                done)        echo "Fertig! Starte mit:" ;;
                uninstalled) echo "Entfernt:" ;;
                notfound)    echo "Nicht gefunden (nichts zu tun):" ;;
                pathtip)     echo "Hinweis: $BINDIR ist nicht in deinem PATH. Ergänze in ~/.bashrc oder ~/.zshrc:" ;;
                deps)        echo "Optionale Abhaengigkeiten pruefen:" ;;
                missing)     echo "  fehlt: $2" ;;
                dephelp)     echo "  Arch: sudo pacman -S $2 | Debian: sudo apt install $2 | Fedora: sudo dnf install $2" ;;
                dl)          echo "Lade smartinfo herunter..." ;;
                dlfail)      echo "Download fehlgeschlagen." ;;
                root)        echo "Root-Rechte fuer $1 werden benoetigt." ;;
            esac
            ;;
        *)
            case $1 in
                title)       echo "smartinfo $VERSION - installer" ;;
                target)      echo "Target" ;;
                copy)        echo "Installing smartinfo to" ;;
                done)        echo "Done! Start with:" ;;
                uninstalled) echo "Removed:" ;;
                notfound)    echo "Not found (nothing to do):" ;;
                pathtip)     echo "Note: $BINDIR is not in your PATH. Add to ~/.bashrc or ~/.zshrc:" ;;
                deps)        echo "Checking optional dependencies:" ;;
                missing)     echo "  missing: $2" ;;
                dephelp)     echo "  Arch: sudo pacman -S $2 | Debian: sudo apt install $2 | Fedora: sudo dnf install $2" ;;
                dl)          echo "Downloading smartinfo..." ;;
                dlfail)      echo "Download failed." ;;
                root)        echo "Root privileges needed for $1." ;;
            esac
            ;;
    esac
}

usage() {
    if [[ $L == de ]]; then
        cat <<EOF
smartinfo $VERSION - Installer

  ./install.sh [OPTIONEN]

  --system          nach /usr/local/bin installieren (mit sudo)
  --prefix DIR      anderes Ziel, Binary landet in DIR/bin
  --uninstall       installierte Version entfernen
  -h, --help        diese Hilfe

Umgebungsvariablen:
  PREFIX, BINDIR, SMARTINFO_RAW_BASE
EOF
    else
        cat <<EOF
smartinfo $VERSION - installer

  ./install.sh [OPTIONS]

  --system          install to /usr/local/bin (uses sudo)
  --prefix DIR      custom prefix, binary goes to DIR/bin
  --uninstall       remove the installed version
  -h, --help        this help

Environment:
  PREFIX, BINDIR, SMARTINFO_RAW_BASE
EOF
    fi
}

while (($#)); do
    case $1 in
        --system)  PREFIX=/usr/local; BINDIR=/usr/local/bin; USE_SUDO=1; shift ;;
        --prefix)  [[ $# -ge 2 ]] || { echo "--prefix braucht einen Wert" >&2; exit 2; }
                   PREFIX=$2; BINDIR=$PREFIX/bin; shift 2 ;;
        --uninstall) MODE=uninstall; shift ;;
        -h|--help) usage; exit 0 ;;
        *)         echo "Unbekannte Option: $1" >&2; usage >&2; exit 2 ;;
    esac
done

as_root() {
    if ((USE_SUDO)) && ((EUID != 0)); then
        sudo "$@"
    else
        "$@"
    fi
}

msg title
echo "  $(msg target): $BINDIR"

if [[ $MODE == uninstall ]]; then
    target="$BINDIR/smartinfo"
    if [[ -e $target ]]; then
        as_root rm -f "$target"
        printf '  %s %s\n' "$(msg uninstalled)" "$target"
    else
        printf '  %s %s\n' "$(msg notfound)" "$target"
    fi
    exit 0
fi

# Quelle bestimmen: lokal vorhanden oder aus dem Netz laden
if self_dir=$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" 2>/dev/null && pwd); then
    :
else
    self_dir=$PWD
fi
source_script="$self_dir/smartinfo"

tmp_script=''
if [[ ! -f $source_script ]]; then
    echo "  $(msg dl)"
    tmp_script=$(mktemp)
    if ! curl -fsSL "$RAW_BASE/smartinfo" -o "$tmp_script"; then
        rm -f "$tmp_script"
        msg dlfail >&2
        exit 1
    fi
    source_script=$tmp_script
fi

cleanup() { if [[ -n $tmp_script ]]; then rm -f "$tmp_script"; fi; }
trap cleanup EXIT

as_root mkdir -p "$BINDIR"
as_root install -m 755 "$source_script" "$BINDIR/smartinfo"

printf '  %s %s\n\n' "$(msg copy)" "$BINDIR/smartinfo"

# Abhaengigkeiten pruefen (Installation selbst braucht keine)
msg deps
for dep in smartctl jq lsblk; do
    if ! command -v "$dep" >/dev/null 2>&1; then
        pkg=$dep
        [[ $dep == smartctl ]] && pkg=smartmontools
        [[ $dep == lsblk ]] && pkg=util-linux
        msg missing "$dep"
        msg dephelp "$pkg"
    fi
done
echo

msg 'done'
echo "  smartinfo          # Uebersicht aller Laufwerke"
echo "  smartinfo -l       # erkannte Laufwerke anzeigen"
echo "  smartinfo --help   # alle Optionen"

case ":$PATH:" in
    *":$BINDIR:"*) ;;
    *) echo
       msg pathtip
       echo "  export PATH=\"$BINDIR:\$PATH\"" ;;
esac
