# Changelog

Alle nennenswerten Änderungen an diesem Projekt.
Format angelehnt an [Keep a Changelog](https://keepachangelog.com/de/1.1.0/),
Versionierung nach [Semantic Versioning](https://semver.org/lang/de/).

## [Unreleased]

### Geändert

- CI läuft nur noch über Gitea Actions auf einem eigenen `act_runner`; der
  GitHub-Workflow ist entfernt. Der CI-Badge ist aus den READMEs entfernt, weil
  er nur eine interne Adresse angezeigt hätte
- `github`-Remote aus dem Arbeits-Repo entfernt; Push nach GitHub erfolgt per URL

### Behoben

- CI: Test „fehlendes jq" legt `smartctl`/`lsblk` als Stubs an, statt Symlinks auf lokal
  installierte Programme zu setzen – auf einem Runner ohne smartmontools schlug der
  Test fehl und meldete fälschlich das fehlende `smartctl`
- `smartinfo -l` prüft jetzt `jq` und meldet die fehlende Abhängigkeit, statt
  „Keine Festplatten gefunden." auszugeben
- `install.sh --uninstall` nennt eine Kopie an anderer Stelle, wenn das Ziel nicht
  zur Installation passt (etwa mit `--system` installiert, ohne `--system` entfernt);
  vorher blieb sie unbemerkt liegen und die Meldung suggerierte Erfolg
- `make uninstall` meldet „nicht installiert", statt auch ohne vorhandene Datei
  „entfernt" auszugeben
- Abhängigkeitsprüfung in `require_cmd` zusammengefasst (`smartctl`, `jq`, `lsblk`)
- README: `mkdir -p ~/.local/bin` in die Ein-Zeilen-Installation aufgenommen – ohne das
  Verzeichnis bricht `curl -o` mit `curl: (23) client returned ERROR on write` ab
- README: eigener Hinweis auf `/usr/local/bin` als Installationsziel auf Servern
  (z. B. Proxmox als `root`), wo `~/.local/bin` nicht im `PATH` liegt
- README: beide Fälle in der Problembehandlung ergänzt

## [1.0.0] - 2026-11-15

### Hinzugefügt

- Übersicht für NVMe-, SATA- und SAS-Laufwerke auf Basis von `smartctl -x --json`
- Health-Status, Temperatur, Laufzeit, Einschaltvorgänge, Abnutzung und Reserve
- Vollständige ATA-Attributtabelle mit Warnfarben und Markierung fehlgeschlagener Attribute
- Automatische Laufwerkserkennung über `lsblk` (zram, loop, dm und md werden ignoriert)
- Deutsche und englische Ausgabe, automatisch aus `$LANG`, umschaltbar per `--lang`
- JSON-Modus (`-j`) für Skripte und Monitoring
- Kurzfassung (`-q`), Laufwerksliste (`-l`), Gerätetyp (`-d`) für USB-Bridges
- Installer (`install.sh`) mit `--system`, `--prefix` und `--uninstall`
- `Makefile` mit `install`, `uninstall`, `test`, `lint`, `check`
- Testsuite mit JSON-Fixtures und Referenzausgaben, ohne Root und ohne `smartctl`
- CI für GitHub Actions und Gitea Actions
