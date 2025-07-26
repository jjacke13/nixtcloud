# 🧊 Nixtcloud: Self-Hosted Cloud in One Command

[![NixOS](https://img.shields.io/badge/NixOS-25.05-blue.svg?style=flat-square&logo=nixos)](https://nixos.org)
[![Nextcloud](https://img.shields.io/badge/Nextcloud-30-orange.svg?style=flat-square&logo=nextcloud)](https://nextcloud.com)
[![Raspberry Pi](https://img.shields.io/badge/Raspberry%20Pi-4%20%7C%205-c51a4a.svg?style=flat-square&logo=raspberry-pi)](https://www.raspberrypi.org)
[![P2P: Holesail](https://img.shields.io/badge/P2P-Holesail-purple.svg?style=flat-square)](https://holesail.io)
[![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-blue.svg)](https://opensource.org/licenses/GPL-3.0)

**Nixtcloud** turns a Raspberry Pi into a privacy-first, zero-config personal cloud — powered by [NixOS](https://nixos.org), [Nextcloud](https://nextcloud.com), and peer-to-peer remote access via [Holesail](https://holesail.io). Built for the self-hosting crowd who want full control without constant babysitting.

---

## 💡 Why Nixtcloud?

> **One command. Full cloud. Private, persistent, and portable.**

- **☁️ Full Nextcloud stack**, pre-configured
- **🔐 End-to-end encrypted remote access**, no port forwarding
- **📦 Plug in USB drives**, they're auto-mounted & usable instantly
- **🔁 Self-healing system** with daily reboots and weekly updates
- **📱 Remote access by QR code**, using Holesail

Perfect for digital minimalists, privacy purists, and anyone fed up with Google Drive.

---

## 🚀 Quick Start

### From NixOS

```bash
nix build --system aarch64-linux github:jjacke13/nixtcloud#packages.aarch64-linux.Rpi4
```

### From macOS/Linux

```bash
nix build --extra-experimental-features nix-command --extra-experimental-features flakes \
  --system aarch64-linux github:jjacke13/nixtcloud#packages.aarch64-linux.Rpi4
```

Flash the resulting image to an SD card, boot your Pi, and visit `http://nixtcloud.local`.

---

## 🧰 What You Need

**Hardware**:
- Raspberry Pi 4 or 5 (≥ 2GB RAM)
- SD card (16GB+)
- Ethernet connection
- Optional: USB drives

**Software**:
- [Nix](https://nixos.org/download.html)
- SD flashing tool (`dd`, [Etcher](https://balena.io/etcher), etc.)

---

## 🧭 First Use

After flashing and booting your Raspberry Pi:

1. **Power On & Wait**  
   The first boot configures the system — this can take up to **3–5 minutes**. Don't interrupt it. The Pi will reboot automatically when ready.

2. **Connect via Ethernet**  
   Make sure the Pi is connected to your local network via Ethernet. Wi-Fi setup (if needed) requires editing `configuration.nix`.

3. **Detect Hostname**  
   From a computer on the same network, open your browser and go to:
   http://nixtcloud.local

   If that doesn't work:
   - Try `ping nixtcloud.local`
   - Or, find the Pi's IP via your router and visit `http://<ip-address>`

4. **Login to Nextcloud**  
   -  Username: `admin`  
   -  Password: `admin`  
   ⚠️ *Change this password immediately* after first login.

5. **Insert USB Storage (Optional)**  
   If you want to expand storage:
   - Plug in a USB drive
   - Wait ~30 seconds
   - It will show up in Nextcloud as external storage

## 🔐 Secure by Design

  - SSH root login disabled by default
  - Firewall restricts all but essential ports
  - Remote access is encrypted, zero-config, and QR-based
  - Weekly auto-updates (or on demand)

---

## 🔄 What Makes It "Self-Healing"?

- Scheduled **daily reboots** at 2:00 AM
- **Systemd recovery** for all critical services
- USB drives auto-mount after 30 seconds
- "Magic files" in Nextcloud let you trigger actions like reboot or regenerate P2P credentials by just deleting a file.

---

## 🔌 Plug & Play External Storage

- Works with ext4, exFAT, FAT32
- Auto-detected and mounted
- Appears in Nextcloud as external storage
- Supports hot-swap and multiple devices

---

## Remote Access with Holesail

To access your Nixtcloud from anywhere in the world:

1. **Install the Holesail app** on your mobile device:
   - [Android](https://play.google.com/store/apps/details?id=io.holesail.holesail.go&pcampaignid=web_share)
   - [iOS](https://apps.apple.com/us/app/holesail-go/id6503728841)
   - Or visit [holesail.io](https://holesail.io) for desktop versions

2. **Connect to your Nextcloud**:
   - Login to your Nixtcloud instance locally
   - Find the `remote.jpg` QR code in your files
   - Open Holesail app and scan the QR code
   - Your Nextcloud is now accessible from anywhere!

No port forwarding, no static IP, no VPN configuration needed - just scan and connect!
---

## ⚙️ Easy Customization

Examples (in `configuration.nix`):

```nix
# WiFi
networking.wireless.enable = true;
networking.wireless.networks = {
  "YourSSID" = { psk = "YourPassword"; };
};

# Disable daily reboots
services.cron.systemCronJobs = [];

# Set timezone
time.timeZone = "Europe/Berlin";
```

---

## 🧱 Under the Hood

- **NixOS** for immutability and reproducibility
- **Nextcloud 30** + PostgreSQL + Redis
- **Holesail** for P2P remote access
- Custom systemd services:
  - `startup.service`
  - `mymnt.service`
  - `p2pmagic.service`
  - `p2public.service`
  - `rebooter.service`

```mermaid
graph TD
  A[nextcloud-setup] --> B[startup.service]
  B --> C[mymnt.service]
  B --> D[p2pmagic.service]
  B --> E[p2public.service]
  B --> F[rebooter.service]
```

---

## 🛠️ Troubleshooting

**Can't access `nixtcloud.local`?**
- Try accessing the Pi's IP address directly
- Ensure `avahi`/mDNS is working on your network

**USB drive not showing up?**
- Check if formatted correctly
- Wait 30 seconds after plugging in
- Run: `journalctl -u mymnt.service`

**Remote access fails?**
- Make sure Holesail app is installed and working
- Double-check the QR or connection string

---

## 🧪 Local Dev & Testing

```bash
git clone https://github.com/jjacke13/nixtcloud.git
cd nixtcloud
nix build .#packages.aarch64-linux.Rpi4
```

(⚠️ Container-based testing coming soon)

---

## 🙌 Credits

- [Holesail](https://holesail.io) for seamless P2P networking
- [Nextcloud](https://nextcloud.com) for the freedom to host your own cloud
- [NixOS](https://nixos.org) for reproducibility that actually works
- Everyone contributing to open source
