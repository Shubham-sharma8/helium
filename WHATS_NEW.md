# What's New in Helium v0.0.2 (Build 2)

**Release Date:** November 2026  
**Download:** `Helium-macOS-Installer.dmg` (Apple Developer Signed • Universal macOS 15.4+)  
**Website:** [cogify.me/helium](https://cogify.me/helium)

---

## Highlights (TL;DR for Website Update Banner)

- **Universal Cloud & Self-Hosted Storage Pool**: Beyond pooling unlimited **Google Drive** accounts, you can now connect **25+ storage providers** into `/Volumes/Helium` — including **Amazon S3**, **Cloudflare R2**, **Backblaze B2**, **Wasabi**, **Hetzner Object Storage**, **DigitalOcean Spaces**, **Storj**, **Tigris**, **Google Cloud Storage (HMAC)**, **Nextcloud / ownCloud / Fastmail / pCloud / Synology WebDAV**, **Hetzner Storage Box (SFTP)**, **rsync.net**, **SMB / Local NAS / Azure Files**, **Dropbox / OneDrive / Box (BYOK)**, and **External USB/Thunderbolt SSDs**.
- **Scheduled Add-Only Mac Folder Backups (`⌘⇧K`)**: Protect `~/Desktop`, `~/Documents`, `~/Pictures`, or any project workspace on an **Hourly, Daily, Weekly, or Manual** schedule with live exclusion-savings previews (`Caches`, `node_modules`, `.git`, `Files > 2 GB`), **Skip on Personal Hotspot**, 14-run history dots, and **add-only safety** (deleting a file on your Mac never deletes its backup copy in `/Volumes/Helium`).
- **Time Travel: Point-in-Time Snapshots & "Then vs. Now" Diffs (`⌘⇧Y`)**: Capture instant snapshots of your entire storage pool, compare **Then vs. Now** visual diffs (`Deleted since then`, `Changed since then`, `Added after snapshot`, `Unchanged`), and 1-click **Restore Copy** or **Restore Version** alongside the 30-day Recently Deleted trash.
- **5-Step Safe-Write & Cryptographic Canary Check**: Verify any connected drive with a 5-step preflight test (*Server RTT latency `ms` → TLS 1.3 handshake → Auth check → Write & read back a cryptographic `SHA-256` canary → Zero-residue cleanup*).
- **Right-Hand File Inspector & Non-Destructive Conflict Resolution**: Toggle the new right-hand File Inspector in `Helium Home` or `Google Drive Pool` to see **"Where it lives"** (exact drive account, segment count, and SHA-256 verification shield), toggle **Keep Downloaded** for offline flights, copy the `/Volumes/Helium/...` path in 1 click, and resolve two-Mac edit conflicts (`Keep Both` vs. `Use Newer`, safely moving the older copy to 30-Day Trash).
- **Status-First Activity & Self-Healing "Needs You" Cards (`⌘⇧A`)**: Real-time dual-series throughput chart (`Sending` + `Streaming HTTP 206` in `MB/s`), reorderable transfer queue (`↑`/`↓`), bandwidth limiter, and 1-click self-healing Fix cards (`idle → Fixing… → Fixed ✓`).
- **Executable Command Palette (`⌃⌥O`)**: Search across all pooled drives and run 1-click actions (`Take Pool Snapshot`, `Run All Mac Backups`, `5-Step Safe-Write Check`, `Connect S3 / R2 / WebDAV / NAS`, `Pause / Resume Transfers`, `Rebalance Pool`, `Undo Last Delete ⌘Z`).
- **Local Privacy Network Contact Map & Redacted Diagnostics**: Open `Settings → Privacy` to see a live visual map of every network host Helium talks to on your Mac (`0` analytics, `0` telemetry), and export a privacy-redacted diagnostic log that strips emails, OAuth tokens, and Mac usernames.

---

## Detailed Feature Breakdown

### 1. Multi-Protocol & Multi-Provider Cloud Support
- **25+ Built-In Service Presets (`StorageServicePreset`)**:
  - **Google Drive Pool**: Link unlimited Google accounts via OAuth 2.0 PKCE (`ASWebAuthenticationSession`) with 64 MiB RAID-0 cross-account striping.
  - **S3-Compatible Object Storage**: Amazon S3, Cloudflare R2 (zero egress), Backblaze B2, Wasabi, Hetzner Object Storage, DigitalOcean Spaces, Storj DCS, Tigris, Google Cloud Storage (HMAC), and MinIO/Garage/Ceph.
  - **WebDAV**: Nextcloud, ownCloud, Fastmail Files, pCloud, and Synology NAS.
  - **SFTP / SSH**: Hetzner Storage Box, rsync.net, and standard SFTP servers.
  - **SMB**: Local NAS / Time Capsule (`_smb._tcp` Bonjour) and Azure Files.
  - **BYOK OAuth Cloud**: Bring your own app key for Dropbox, Microsoft OneDrive, or Box.
  - **Local / External SSD**: Pool an external USB/Thunderbolt drive alongside your cloud accounts.
- **Smart Endpoint & Region Inference**: Paste any S3 or WebDAV URL and Helium automatically identifies the provider preset and extracts the S3 signing region (`auto`, `us-east-1`, `eu-west-1`, etc.).

### 2. 5-Step Safe-Write Verification (`SafeWriteVerifier`)
Before trusting a storage endpoint (or anytime from the **Activity & Health** tab), Helium runs five measured checks:
1. **Reach the server**: Measures round-trip latency in `ms`.
2. **Secure connection**: Verifies the `TLS 1.3` / `TLS 1.2` certificate chain.
3. **Sign in & verify permissions**: Confirms bucket/vault read & list access.
4. **Test safe reads & writes**: Writes a temporary canary payload, reads it back, and verifies its `SHA-256` digest matches byte-for-byte.
5. **Zero-residue cleanup**: Removes the temporary canary and confirms `0 B` left behind.

### 3. Scheduled Add-Only Mac Folder Backups (`HeliumBackupEngine`)
- **One-Click Folder Presets**: Protect `~/Desktop`, `~/Documents`, or `~/Pictures` in one click, or pick any custom folder on your Mac.
- **Live Folder Scan & Exclusion Preview**: Before creating a backup job, Helium scans the folder locally and displays the exact file count and gigabytes saved by skipping `Caches`, `node_modules`, `.git`, `.DS_Store`, `.photoslibrary`, `.fcpbundle`, or single files `> 2 GB`.
- **Add-Only Cloud Safety**: Backups are strictly one-way and version-preserving — deleting a file on your Mac **never** deletes its backup copy in `/Volumes/Helium/Backups`.
- **Countdown Ring & 14-Run History Dots**: Visual countdown ring to the next scheduled run (`Every Hour`, `Every Day`, `Every Week`, or `Manual Only`), `Skip on Personal Hotspot` toggle, and color-coded status dots for the last 14 runs.

### 4. Time Travel: Snapshots & "Then vs. Now" Diffing (`SnapshotTimelineManager`)
- **Point-in-Time Pool Snapshots**: Capture the complete manifest state of `/Volumes/Helium` at any moment with a title and note (e.g., *"Before Final Cut color grade"*).
- **Visual "Then vs. Now" Comparison**: Every item in a snapshot is compared against your live pool and badged as:
  - `Deleted since then` (Orange)
  - `Changed since then` (Blue — shows `THEN` size vs. `NOW` size)
  - `Added after snapshot` (Purple)
  - `Unchanged` (Green)
- **One-Click Recovery**: Restore any snapshot item as a non-destructive copy (`Restore Copy`) or revert it in place (`Restore Version`).
- **Unified 30-Day Recently Deleted Trash**: Switch between *Past Versions (Snapshots)* and *Recently Deleted (30-Day Trash)* in one place.

### 5. Right-Hand File Inspector & Conflict Resolution
- **Collapsible Inspector Drawer**: Click the right-sidebar icon in the toolbar while browsing `Helium Home` or `Google Drive Pool` to inspect any file or folder:
  - **Verification & Placement Badge**: Shows `Verified • 0 B on Mac`, `Striped (N segments)`, `Kept on this Mac`, or `2 Versions (Conflict)`.
  - **"Where It Lives" Card**: Displays the exact Google Drive account email, placement mode (`Mode 1 Whole-File` vs. `Mode 2 64 MiB Striped`), and `AES-256-GCM` / `SHA-256` verification status.
  - **Keep Downloaded Switch**: Pin or unpin files for offline use without Wi-Fi.
  - **Copy Path Chip**: 1-click copy of `/Volumes/Helium/<filename>`.
- **Non-Destructive Conflict Resolver**: When a file is edited on two Macs simultaneously, both versions are preserved and you can resolve the conflict in one click with **Keep Both** or **Use Newer** (which safely moves the older copy to the 30-Day Recycle Bin).

### 6. Status-First Activity, Throughput Chart & Privacy Audit Ledger
- **Actionable "Needs You" Cards**: Issues such as an unmounted drive, a two-version file conflict, an account below 512 MB free, or an unverified session canary appear as self-healing cards with a 1-click fix button (`idle → Fixing… → Fixed ✓`).
- **Live Dual-Series Throughput Chart**: Rolling 2-minute area chart tracking both `Sending to Pool` and `Streaming to Mac (HTTP Range 206)` speeds with smooth monospaced `.rollingNumber()` transitions.
- **Privacy Network Contact Map (`Settings → Privacy`)**: Visual Bezier map from `This Mac (/Volumes/Helium)` to every host Helium has contacted, showing request count and last-contact time, plus a **Save Redacted Log…** button that strips email addresses, OAuth tokens (`ya29.*`, `1//*`), and `/Users/<username>` paths before saving to `~/Downloads`.
