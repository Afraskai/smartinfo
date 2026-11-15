#!/usr/bin/env bash
# Testsuite fuer smartinfo - laeuft ohne smartctl und ohne Root.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

pass=0
fail=0

ok()  { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
nok() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; }

render() {
    # render <sprache> <fixture> [quiet]
    SMARTINFO_LANG=$1 QUIET=${3:-0} NO_COLOR=1 TERM=dumb \
        bash -c 'source ./smartinfo; render_device /dev/test "$(cat "$1")"' _ "$2"
}

VERSION=$(sed -n 's/^VERSION="\(.*\)"/\1/p' smartinfo)

echo "smartinfo tests"

# 1. Syntax
if bash -n smartinfo; then
    ok "bash -n (Syntax)"
else
    nok "bash -n (Syntax)"
fi

# 2. Version
out=$(./smartinfo -V 2>&1)
if [[ $out =~ ^smartinfo\ [0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    ok "--version ($out)"
else
    nok "--version (war: $out)"
fi

# 3. Hilfe
out=$(./smartinfo -h 2>&1)
if [[ $out == *smartinfo* && $out == *--json* ]]; then
    ok "--help"
else
    nok "--help"
fi

# 4. Ausgabe gegen Referenzdateien
for fixture in nvme-healthy sata-warning nvme-failing nvme-worn; do
    for lang in de en; do
        expected="tests/expected/${fixture}.${lang}.txt"
        if diff -u "$expected" <(render "$lang" "tests/fixtures/${fixture}.json") >/tmp/smartinfo-diff.$$ 2>&1; then
            ok "render $fixture ($lang)"
        else
            nok "render $fixture ($lang)"
            sed 's/^/       /' /tmp/smartinfo-diff.$$
        fi
        rm -f /tmp/smartinfo-diff.$$
    done
done

# 5. --quiet blendet die Attributtabelle aus
out=$(render de tests/fixtures/sata-warning.json 1)
if [[ $out != *Attribut* ]]; then
    ok "--quiet ohne Attributtabelle"
else
    nok "--quiet ohne Attributtabelle"
fi

# 6. Unbekannte Option
./smartinfo --gibtsnicht >/dev/null 2>&1
if [[ $? -eq 1 ]]; then
    ok "unbekannte Option -> Exitcode 1"
else
    nok "unbekannte Option -> Exitcode 1"
fi

# 7. Sprachumschaltung per --lang schlaegt $LANG
out=$(LANG=de_DE.UTF-8 SMARTINFO_LANG=en ./smartinfo --lang=en -V 2>&1)
if [[ $out == "smartinfo $VERSION" ]]; then
    ok "--lang=en"
else
    nok "--lang=en (war: $out)"
fi

# 8. Fehlende Abhaengigkeit wird gemeldet (smartctl vorhanden, jq nicht)
#    smartctl/lsblk als Stubs: der Test darf nicht davon abhaengen, ob
#    smartmontools auf dem Runner installiert ist (CI hat es nicht).
tmpbin=$(mktemp -d)
ln -s "$(command -v bash)" "$tmpbin/bash"
printf '#!/bin/sh\nexit 0\n' >"$tmpbin/smartctl"
printf '#!/bin/sh\nexit 0\n' >"$tmpbin/lsblk"
chmod +x "$tmpbin/smartctl" "$tmpbin/lsblk"
out=$(PATH="$tmpbin" bash smartinfo /dev/null 2>&1)
rc=$?
rm -rf "$tmpbin"
if [[ $rc -eq 1 && $out == *jq* ]]; then
    ok "fehlendes jq -> Hinweis"
else
    nok "fehlendes jq -> Hinweis (rc=$rc, out=$out)"
fi

# 8b. Auch die Laufwerksliste (-l) braucht jq - Hinweis statt "keine Laufwerke"
tmpbin=$(mktemp -d)
ln -s "$(command -v bash)" "$tmpbin/bash"
printf '#!/bin/sh\nexit 0\n' >"$tmpbin/lsblk"
chmod +x "$tmpbin/lsblk"
out=$(PATH="$tmpbin" bash smartinfo -l 2>&1)
rc=$?
rm -rf "$tmpbin"
if [[ $rc -eq 1 && $out == *jq* ]]; then
    ok "fehlendes jq bei -l -> Hinweis"
else
    nok "fehlendes jq bei -l -> Hinweis (rc=$rc, out=$out)"
fi

# 9. Kompletter Ablauf mit Stub-smartctl und Stub-sudo (kein Root noetig)
tmpbin=$(mktemp -d)
printf '#!/bin/sh\nexec "$@"\n' >"$tmpbin/fakesudo"
printf '#!/bin/sh\ncat %s\n' "$PWD/tests/fixtures/nvme-healthy.json" >"$tmpbin/smartctl"
chmod +x "$tmpbin/fakesudo" "$tmpbin/smartctl"
out=$(PATH="$tmpbin:$PATH" SMARTINFO_SUDO="$tmpbin/fakesudo" SMARTINFO_LANG=de NO_COLOR=1 \
      ./smartinfo /dev/test 2>&1)
rc=$?
rm -rf "$tmpbin"
if [[ $rc -eq 0 && $out == "$(cat tests/expected/nvme-healthy.de.txt)" ]]; then
    ok "Ende-zu-Ende mit Stub-smartctl"
else
    nok "Ende-zu-Ende mit Stub-smartctl (rc=$rc)"
fi

# 10. Installer installiert und entfernt in einem Wegwerf-Ziel
tmpdir=$(mktemp -d)
SMARTINFO_LANG=de ./install.sh --prefix "$tmpdir" >/dev/null 2>&1
installed=0; [[ -x $tmpdir/bin/smartinfo ]] && installed=1
SMARTINFO_LANG=de ./install.sh --prefix "$tmpdir" --uninstall >/dev/null 2>&1
gone=0; [[ ! -e $tmpdir/bin/smartinfo ]] && gone=1
rm -rf "$tmpdir"
if ((installed == 1 && gone == 1)); then
    ok "install.sh installieren und entfernen"
else
    nok "install.sh installieren und entfernen (installed=$installed gone=$gone)"
fi

# 11. Deinstallation ohne Installation meldet das und endet mit 0
tmpdir=$(mktemp -d)
out=$(HOME="$tmpdir" SMARTINFO_LANG=de ./install.sh --prefix "$tmpdir/leer" --uninstall 2>&1)
rc=$?
rm -rf "$tmpdir"
if [[ $rc -eq 0 && $out == *"Nicht gefunden"* ]]; then
    ok "Deinstallation ohne Installation -> Hinweis"
else
    nok "Deinstallation ohne Installation -> Hinweis (rc=$rc, out=$out)"
fi

# 12. Falsches Ziel entfernt nichts Fremdes, nennt aber die andere Fundstelle
tmpdir=$(mktemp -d)
mkdir -p "$tmpdir/.local/bin" "$tmpdir/ziel/bin"
cp smartinfo "$tmpdir/.local/bin/smartinfo"
out=$(HOME="$tmpdir" SMARTINFO_LANG=de ./install.sh --prefix "$tmpdir/ziel" --uninstall 2>&1)
rc=$?
still_there=0; [[ -e $tmpdir/.local/bin/smartinfo ]] && still_there=1
rm -rf "$tmpdir"
if [[ $rc -eq 0 && $still_there -eq 1 && $out == *"Noch vorhanden"* ]]; then
    ok "Deinstallation nennt andere Fundstelle"
else
    nok "Deinstallation nennt andere Fundstelle (rc=$rc, still=$still_there, out=$out)"
fi

# 13. Meldung von smartctl selbst (smartctl.messages) wird angezeigt
#     Ohne sie bleibt ein fehlgeschlagenes Oeffnen des Geraets unerklaert.
out=$(render de tests/fixtures/no-device.json)
if [[ $out == *"No such device"* ]]; then
    ok "smartctl-Meldung wird angezeigt"
else
    nok "smartctl-Meldung wird angezeigt (war: $out)"
fi

# 14. Nicht lesbares Geraet -> Exitcode 1 statt faelschlich 0
tmpbin=$(mktemp -d)
printf '#!/bin/sh\ncat %s\n' "$PWD/tests/fixtures/no-device.json" >"$tmpbin/smartctl"
printf '#!/bin/sh\nexec "$@"\n' >"$tmpbin/fakesudo"
chmod +x "$tmpbin/smartctl" "$tmpbin/fakesudo"
PATH="$tmpbin:$PATH" SMARTINFO_SUDO="$tmpbin/fakesudo" ./smartinfo /dev/test >/dev/null 2>&1
rc=$?
rm -rf "$tmpbin"
if [[ $rc -eq 1 ]]; then
    ok "nicht lesbares Geraet -> Exitcode 1"
else
    nok "nicht lesbares Geraet -> Exitcode 1 (rc=$rc)"
fi

# 15. Jedes gesetzte Critical-Warning-Bit wird im Klartext benannt
out=$(render de <(printf '%s' '{"smart_status":{"passed":true},"nvme_smart_health_information_log":{"critical_warning":63}}'))
if [[ $out == *"Reserve unter Schwelle"* && $out == *"Zuverlässigkeit herabgesetzt"* &&
      $out == *"schreibgeschützt"* && $out == *"Weitere Critical-Warning-Bits"* ]]; then
    ok "Critical-Warning-Bits werden benannt"
else
    nok "Critical-Warning-Bits werden benannt (war: $out)"
fi

# 16. SMART-Status FAILED erscheint als FEHLER
#     jq behandelt false wie einen leeren Wert, ".passed // \"\"" verschluckte ihn.
out=$(render de <(printf '%s' '{"model_name":"Test","smart_status":{"passed":false}}'))
if [[ $out == *"FEHLER"* ]]; then
    ok "SMART-Status FAILED -> FEHLER"
else
    nok "SMART-Status FAILED -> FEHLER (war: $out)"
fi

printf '\n%d bestanden, %d fehlgeschlagen\n' "$pass" "$fail"
((fail == 0))
