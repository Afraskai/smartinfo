# smartinfo

[![CI](http://192.168.0.95:3000/grossegurke/smartinfo/actions/workflows/ci.yml/badge.svg)](http://192.168.0.95:3000/grossegurke/smartinfo/actions/workflows/ci.yml)
[![Lizenz: MIT](https://img.shields.io/badge/Lizenz-MIT-blue.svg)](LICENSE)
![Bash](https://img.shields.io/badge/bash-4%2B-4EAA25?logo=gnubash&logoColor=white)

**SMART-Werte deiner Festplatten im Terminal – wie CrystalDiskInfo bzw. QDiskInfo, nur ohne GUI.**

Ein Ein-Datei-Skript. Kein Build, kein Qt, keine Installation von 200 MB Bibliotheken.
Es liest die Daten mit `smartctl` (smartmontools) und zeigt sie als kompakte Übersicht:
Health-Status, Temperatur, Laufzeit, Abnutzung und – bei SATA-Platten – die komplette
Attributtabelle mit Warnfarben.

```
/dev/nvme0n1  INTEL SSDPEKKF256G8
  Status              GUT
  Kapazität          256.1 GB
  Anschluss           NVMe
  Firmware            004C
  Seriennummer        BTPY123456ABCDEF
  Temperatur          41 °C
  Laufzeit            12345 h (1 Jahr, 149 Tage)
  Einschaltungen      1234
  Abnutzung           3 % (Percentage Used)
  Reserve             100 % (Schwelle 10 %)
  Gelesen             25.0 TB
  Geschrieben         6.2 TB
  Unsichere Stopps    42
  Media Errors        0
  Fehler-Log          7
```

---

## Installation

### Variante 1: zwei Zeilen (empfohlen)

```bash
mkdir -p ~/.local/bin
curl -fsSL https://raw.githubusercontent.com/Afraskai/smartinfo/main/smartinfo \
  -o ~/.local/bin/smartinfo && chmod +x ~/.local/bin/smartinfo
```

`mkdir -p` gehört dazu: `curl -o` legt keine Verzeichnisse an. Fehlt `~/.local/bin`,
bricht der Download mit `curl: (23) client returned ERROR on write` ab.

`~/.local/bin` ist bei den meisten Distributionen bereits im `PATH`.
Falls nicht: `export PATH="$HOME/.local/bin:$PATH"` in die `~/.bashrc` / `~/.zshrc`.

**Auf Servern** (Proxmox, Debian/Ubuntu als `root`) ist `~/.local/bin` meist **nicht**
im `PATH`. Dort direkt nach `/usr/local/bin` installieren:

```bash
curl -fsSL https://raw.githubusercontent.com/Afraskai/smartinfo/main/smartinfo \
  -o /usr/local/bin/smartinfo && chmod +x /usr/local/bin/smartinfo
```

Alternativ Variante 2 mit `--system` – der Installer legt alle Verzeichnisse selbst an.

### Variante 2: mit Installer

```bash
git clone https://github.com/Afraskai/smartinfo.git
cd smartinfo
./install.sh              # nach ~/.local/bin
./install.sh --system     # nach /usr/local/bin (mit sudo)
```

Der Installer prüft auch, ob `smartctl`, `jq` und `lsblk` vorhanden sind.

### Variante 3: klassisch

```bash
git clone https://github.com/Afraskai/smartinfo.git
cd smartinfo
sudo make install         # PREFIX=/usr/local
make install              # oder nach ~/.local
```

### Abhängigkeiten

| Programm | Paket | Wofür |
|---|---|---|
| `smartctl` | `smartmontools` | liefert die SMART-Daten |
| `jq` | `jq` | JSON-Auswertung |
| `lsblk` | `util-linux` | Laufwerke finden (fast überall dabei) |

```bash
# Arch / CachyOS / Manjaro
sudo pacman -S smartmontools jq
# Debian / Ubuntu / Mint
sudo apt install smartmontools jq
# Fedora
sudo dnf install smartmontools jq
```

---

## Benutzung

```bash
smartinfo                       # alle Laufwerke
smartinfo /dev/nvme0n1          # nur dieses Laufwerk
smartinfo -q                    # Kurzfassung ohne Attributtabelle
smartinfo -l                    # erkannte Laufwerke auflisten (ohne Root)
```

| Option | Bedeutung |
|---|---|
| `-q`, `--quiet` | nur Status/Health, keine Attributtabelle |
| `-l`, `--list` | erkannte Datenträger anzeigen, ohne Root |
| `-j`, `--json` | rohes `smartctl`-JSON ausgeben (für Skripte) |
| `-d`, `--device=TYPE` | `smartctl -d TYPE`, z. B. `sat` für USB-Gehäuse |
| `--lang=de\|en` | Sprache der Ausgabe (Default aus `$LANG`) |
| `--no-color` | Farben aus |
| `-V`, `--version` | Version |
| `-h`, `--help` | Hilfe |

### Beispiele

```bash
# Nur die wichtigsten Werte, gut für Screenshots oder Monitoring
smartinfo -q

# JSON weiterverarbeiten
smartinfo -j /dev/nvme0n1 | jq '.nvme_smart_health_information_log.percentage_used'

# USB-Festplatte hinter einer SAT-Bridge
smartinfo -d sat /dev/sdb

# Temperatur aller Platten in einer Zeile
for d in /dev/sd? /dev/nvme?n1; do
    [ -e "$d" ] && smartinfo -j "$d" | jq -r --arg d "$d" '"\($d): \(.temperature.current) °C"'
done
```

### Farben

- **grün** – alles gut
- **gelb** – Warnung (Temperatur ≥ 50 °C, Abnutzung ≥ 70 %, Attribut nahe Schwelle)
- **rot** – kritisch (SMART-Status *FAILED*, Temperatur ≥ 60 °C, Abnutzung ≥ 90 %, Attribut fehlgeschlagen)

### JSON-Modus

`smartinfo -j` gibt exakt die JSON-Struktur von `smartctl -x --json` aus. Damit kannst du
alles weiterverarbeiten, was die Anzeige verwendet – z. B. in Prometheus-Exporter, Skripten
oder einer eigenen GUI.

---

## Warum sudo?

SMART-Daten sind Hardware-Informationen, die der Kernel nur mit Root-Rechten herausgibt.
`smartinfo` ruft deshalb – genau wie QDiskInfo – `smartctl` per `sudo` auf. Du wirst
**einmal** nach dem Passwort gefragt, danach gilt es für alle Laufwerke des Aufrufs.

Das Skript selbst läuft ohne Root, führt keine Schreibzugriffe aus und öffnet keine
Netzwerkverbindungen. Es liest ausschließlich `smartctl`-Ausgaben.

Wer kein `sudo` mag:

```bash
SMARTINFO_SUDO=doas smartinfo
```

---

## Problembehandlung

| Problem | Lösung |
|---|---|
| `curl: (23) … ERROR on write` | Zielverzeichnis fehlt → `mkdir -p ~/.local/bin`, danach erneut herunterladen |
| `smartinfo: command not found` nach `~/.local/bin`-Installation | Verzeichnis nicht im `PATH` (typisch als `root`) → nach `/usr/local/bin` installieren oder `PATH` ergänzen |
| `Konnte /dev/sdX nicht lesen` | Rechte fehlen → mit `sudo` ausführen oder `SMARTINFO_SUDO` setzen |
| USB-Platte liefert keine Daten | `smartinfo -d sat /dev/sdb` (oder `-d usbjmicron`, `-d usbcypress`) |
| „jq fehlt“ | `sudo pacman -S jq` / `sudo apt install jq` |
| Keine Laufwerke gefunden | `lsblk` prüfen, ggf. Gerät direkt angeben |
| NVMe zeigt keine Attribute | normal: NVMe hat kein ATA-Attributset, die Health-Werte stehen oben |
| Englische Ausgabe gewünscht | `smartinfo --lang=en` oder `SMARTINFO_LANG=en` |

---

## Deinstallation

```bash
./install.sh --uninstall
# oder
make uninstall
# oder einfach
rm ~/.local/bin/smartinfo
```

---

## Entwicklung

```bash
make test      # Testsuite (ohne smartctl, ohne Root)
make lint      # shellcheck
make check     # beides
```

Die Tests rendern feste JSON-Fixtures (`tests/fixtures/`) und vergleichen mit
Referenzausgaben (`tests/expected/`) – so bleiben Formatierung und beide Sprachen stabil.
CI läuft über Gitea Actions auf einem eigenen Runner (`.gitea/workflows/ci.yml`).

## Lizenz

MIT – siehe [LICENSE](LICENSE).

Englische Dokumentation: [README.en.md](README.en.md)
