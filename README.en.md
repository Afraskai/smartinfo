# smartinfo

[![CI](http://192.168.0.95:3000/grossegurke/smartinfo/actions/workflows/ci.yml/badge.svg)](http://192.168.0.95:3000/grossegurke/smartinfo/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![Bash](https://img.shields.io/badge/bash-4%2B-4EAA25?logo=gnubash&logoColor=white)

**SMART data for your disks in the terminal – like CrystalDiskInfo / QDiskInfo, without the GUI.**

A single bash script. No build step, no Qt, no 200 MB of libraries. It reads the data
with `smartctl` (smartmontools) and prints a compact overview: health status, temperature,
power-on time, wear and – for SATA drives – the full attribute table with warning colors.

```
/dev/nvme0n1  INTEL SSDPEKKF256G8
  Status              GOOD
  Capacity            256.1 GB
  Interface           NVMe
  Firmware            004C
  Serial              BTPY123456ABCDEF
  Temperature         41 °C
  Power-on time       12345 h (1 year, 149 days)
  Power cycles        1234
  Wear                3 % (percentage used)
  Spare               100 % (threshold 10 %)
  Read                25.0 TB
  Written             6.2 TB
  Unsafe shutdowns    42
  Media errors        0
  Error log           7
```

---

## Install

### One-liner (recommended)

```bash
mkdir -p ~/.local/bin
curl -fsSL https://raw.githubusercontent.com/Afraskai/smartinfo/main/smartinfo \
  -o ~/.local/bin/smartinfo && chmod +x ~/.local/bin/smartinfo
```

The `mkdir -p` matters: `curl -o` does not create directories. If `~/.local/bin` is
missing, the download fails with `curl: (23) client returned ERROR on write`.

`~/.local/bin` is in `PATH` on most distributions. If not, add
`export PATH="$HOME/.local/bin:$PATH"` to your `~/.bashrc` / `~/.zshrc`.

**On servers** (Proxmox, Debian/Ubuntu as `root`), `~/.local/bin` is usually **not** in
`PATH`. Install to `/usr/local/bin` directly instead:

```bash
curl -fsSL https://raw.githubusercontent.com/Afraskai/smartinfo/main/smartinfo \
  -o /usr/local/bin/smartinfo && chmod +x /usr/local/bin/smartinfo
```

Or use the installer with `--system` (option 2) – it creates the directories itself.

### With the installer

```bash
git clone https://github.com/Afraskai/smartinfo.git
cd smartinfo
./install.sh              # to ~/.local/bin
./install.sh --system     # to /usr/local/bin (sudo)
```

### Classic

```bash
git clone https://github.com/Afraskai/smartinfo.git
cd smartinfo
sudo make install         # PREFIX=/usr/local
make install              # or to ~/.local
```

### Dependencies

| Program | Package | Purpose |
|---|---|---|
| `smartctl` | `smartmontools` | provides the SMART data |
| `jq` | `jq` | JSON parsing |
| `lsblk` | `util-linux` | disk discovery (usually preinstalled) |

```bash
sudo pacman -S smartmontools jq   # Arch / CachyOS / Manjaro
sudo apt install smartmontools jq # Debian / Ubuntu / Mint
sudo dnf install smartmontools jq # Fedora
```

---

## Usage

```bash
smartinfo                       # all disks
smartinfo /dev/nvme0n1          # a single disk
smartinfo -q                    # summary only, no attribute table
smartinfo -l                    # list detected disks (no root)
```

| Option | Meaning |
|---|---|
| `-q`, `--quiet` | health summary only |
| `-l`, `--list` | list detected disks, no root needed |
| `-j`, `--json` | raw `smartctl` JSON (for scripting) |
| `-d`, `--device=TYPE` | `smartctl -d TYPE`, e.g. `sat` for USB enclosures |
| `--lang=de\|en` | output language (default from `$LANG`) |
| `--no-color` | disable colors |
| `-V`, `--version` | version |
| `-h`, `--help` | help |

### Examples

```bash
smartinfo -q                                     # the important bits only
smartinfo -j /dev/nvme0n1 | jq '.temperature'    # JSON for your own tooling
smartinfo -d sat /dev/sdb                        # USB drive behind a SAT bridge
```

### Colors

- **green** – fine
- **yellow** – warning (≥ 50 °C, wear ≥ 70 %, attribute near threshold)
- **red** – critical (SMART *FAILED*, ≥ 60 °C, wear ≥ 90 %, failed attribute)

---

## Why sudo?

SMART data is hardware information the kernel only exposes to root. Like QDiskInfo,
`smartinfo` calls `smartctl` through `sudo`, asking for your password **once** per run.

The script itself does not run as root, performs no writes and makes no network
connections. It only reads `smartctl` output.

```bash
SMARTINFO_SUDO=doas smartinfo   # if you prefer doas
```

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `curl: (23) … ERROR on write` | target directory missing → `mkdir -p ~/.local/bin`, then download again |
| `smartinfo: command not found` after installing to `~/.local/bin` | directory not in `PATH` (typical for `root`) → install to `/usr/local/bin` or extend `PATH` |
| `Could not read /dev/sdX` | missing privileges → run with sudo or set `SMARTINFO_SUDO` |
| USB drive returns nothing | `smartinfo -d sat /dev/sdb` (also `usbjmicron`, `usbcypress`, …) |
| “jq is missing” | `sudo pacman -S jq` / `sudo apt install jq` |
| No disks found | check `lsblk`, or pass the device explicitly |
| NVMe shows no attribute table | normal: NVMe has no ATA attribute set, health values are above |
| German output wanted | `smartinfo --lang=de` or `SMARTINFO_LANG=de` |

---

## Uninstall

```bash
./install.sh --uninstall
# or
make uninstall
# or simply
rm ~/.local/bin/smartinfo
```

---

## Development

```bash
make test      # test suite (no smartctl, no root)
make lint      # shellcheck
make check     # both
```

Tests render fixed JSON fixtures (`tests/fixtures/`) and compare them against
reference output (`tests/expected/`) so formatting and both languages stay stable.
CI runs on Gitea Actions (`.gitea/workflows/ci.yml`).

## License

MIT – see [LICENSE](LICENSE).

Deutsche Dokumentation: [README.md](README.md)
