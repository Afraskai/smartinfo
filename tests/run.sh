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
for fixture in nvme-healthy sata-warning nvme-failing; do
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

printf '\n%d bestanden, %d fehlgeschlagen\n' "$pass" "$fail"
((fail == 0))
