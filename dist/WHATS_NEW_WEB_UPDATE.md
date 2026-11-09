# What's New in Helium v0.0.2 (Build 2) — Web Update & Release Notes

**Release Date:** November 2026  
**Installer:** `Helium-macOS-Installer.dmg` (Apple Developer Signed • Universal macOS 15.4+)  
**Website:** [cogify.me/helium](https://cogify.me/helium)

---

## Copy-Paste Web Update Banner / Changelog Card (`cogify.me/helium`)

### Headline
**Helium v0.0.2 — Universal Storage Pool, Scheduled Mac Backups, Time Travel Snapshots & 5-Step Safe-Write Verification**

### What's New
- **Pool 25+ Cloud & Self-Hosted Storage Providers**: Combine unlimited **Google Drives** alongside **Amazon S3**, **Cloudflare R2**, **Backblaze B2**, **Wasabi**, **Hetzner Object Storage**, **DigitalOcean Spaces**, **Storj**, **Tigris**, **Google Cloud Storage (HMAC)**, **Nextcloud / ownCloud / Fastmail / pCloud / Synology WebDAV**, **Hetzner Storage Box (SFTP)**, **rsync.net**, **SMB / Local NAS / Azure Files**, **Dropbox / OneDrive / Box (BYOK)**, and **External SSDs** inside `/Volumes/Helium`.
- **Scheduled Add-Only Mac Folder Backups (`⌘⇧K`)**: Automatically back up `~/Desktop`, `~/Documents`, `~/Pictures`, or any project folder to `/Volumes/Helium/Backups` (`Hourly`, `Daily`, `Weekly`, or `Manual`). Includes live folder scan previews showing exact gigabytes saved by skipping `Caches`, `node_modules`, and `>2 GB` files, **Skip on Personal Hotspot**, a countdown ring, 14-run history dots, and **add-only safety** (deleting a local file on your Mac never deletes its cloud backup copy).
- **Time Travel: Point-in-Time Snapshots & "Then vs. Now" Diffs (`⌘⇧Y`)**: Capture instant snapshots of your storage pool, inspect **Then vs. Now** visual diffs (`Deleted since then`, `Changed since then`, `Added after snapshot`, `Unchanged`), and 1-click **Restore Copy** or **Restore Version** alongside the 30-day Recently Deleted trash.
- **5-Step Safe-Write Cryptographic Canary Check**: Every storage connection can run a 5-step preflight check (*Server RTT latency `ms` → TLS 1.3 handshake → Auth check → Write & read back a `SHA-256` canary → Zero-residue cleanup*).
- **Right-Hand File Inspector & Conflict Resolver**: Toggle the collapsible File Inspector in `Helium Home` or `Google Drive Pool` to see **"Where it lives"**, toggle **Keep Downloaded** for offline use, copy the `/Volumes/Helium/...` path in 1 click, and non-destructively resolve two-Mac edit conflicts (**Keep Both** vs. **Use Newer**).
- **Status-First Activity & Self-Healing "Needs You" Cards (`⌘⇧A`)**: Live dual-series Sending/Streaming (`HTTP 206`) throughput chart (`MB/s`), reorderable transfer queue (`↑`/`↓`), bandwidth limiter, and 1-click self-healing Fix cards (`idle → Fixing… → Fixed ✓`).
- **Executable Command Palette (`⌃⌥O`)**: Search files across all pooled drives and trigger 1-click commands (`Take Pool Snapshot`, `Run All Mac Backups`, `5-Step Safe-Write Check`, `Connect S3 / R2 / WebDAV / NAS`, `Pause / Resume Transfers`, `Rebalance Pool`, `Undo Last Delete ⌘Z`).
- **Local Privacy Network Contact Map & Redacted Diagnostics**: View a real-time Bezier network map in `Settings → Privacy` counting every host Helium contacts (`0` analytics, `0` telemetry), plus 1-click export of privacy-redacted diagnostic logs (stripping emails, OAuth tokens, and Mac usernames).
