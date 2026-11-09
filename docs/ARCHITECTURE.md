# Helium Architecture & Engineering Guide

Helium is a native macOS application and virtual filesystem engine written in Swift that pools multiple Google Drive accounts into a single mountable volume at `/Volumes/Helium`.

---

## 1. High-Level Module Breakdown

| Target | Path | Responsibility |
| :--- | :--- | :--- |
| **`OrbitCore`** | `Sources/OrbitCore/` | Core library: Multi-Google-Drive storage pool, placement allocator, `AES-256-GCM` zero-knowledge crypto (`ZK`), `ChunkStore`, `ContentReader`, `DriveTree`, and `UploadGovernor`. |
| **`HeliumApp`** | `Sources/HeliumApp/` | Main macOS SwiftUI application, menu bar extra, Google OAuth 2.0 PKCE coordinator, and real-time virtual filesystem coordinator (`HeliumRealtimeVFSServer`). |
| **`HeliumOpener`** | `Sources/HeliumOpener/` | Background (`LSUIElement`) launcher app that intercepts double-clicks on 0-byte sparse placeholders in `/Volumes/Helium`, streams or materializes the file on demand, and opens it directly in the native default macOS app (`QuickTime`, `Preview`, `DiskImageMounter`, etc.). |
| **`OrbitFS`** | `Sources/OrbitFS/` | FSKit unary filesystem module implementing `FSUnaryFileSystem` and `FSVolume` operations backed by `OrbitDrive`. |
| **`OrbitFinder`** | `Sources/OrbitFinder/` | FinderSync extension providing contextual menu actions (`Copy Helium Link`, `Keep Offline on This Mac`) and sync badges. |
| **`OrbitMountHelper`** | `Sources/OrbitMountHelper/` | Privileged/helper executable for managing `/Volumes/Helium` lifecycle. |

---

## 2. Multi-Account Google Drive Pool (`PooledGoogleDriveRemote`)

### 2.1 Pool Catalog & Manifests (`PooledFileManifest`)
Every file stored in Helium's Google Drive Pool is tracked by a `PooledFileManifest` containing:
- Logical file metadata (`RemoteItem`: ID, parent folder ID, logical byte size, modification date, starred/trashed flags).
- `placementMode`: `.wholeFileSmartPlacement` or `.crossAccountStriped`.
- Ordered `segments` (`[PooledFileSegment]`): Each segment maps a contiguous byte range (`logicalOffset`, `byteLength`, `encryptedByteLength`) to a specific `accountId` and `googleDriveFileId`, along with an optional `sha256Hex` digest.

### 2.2 Dual-Mode Storage Placement (`StoragePoolAllocator`)
When uploading a file of size `S`:
1. **Whole-File Smart Placement (`.wholeFileSmartPlacement`)**:
   - If `S <= autoStripeAboveBytes` and at least one non-paused linked Google Drive account has `allocatableBytes >= S`, the allocator routes the entire file to a single account according to the active `PoolRoutingStrategy`:
     - `.priorityOrder`: Selects the highest-priority account (lowest `uploadPriority` rank) that can fit `S`.
     - `.mostFreeSpace`: Selects the account with the largest available free space.
     - `.pinnedAccount`: Routes to a user-pinned account ID if space permits.
2. **Cross-Account RAID-0 Segment Striping (`.crossAccountStriped`)**:
   - If `S` exceeds the free space of every individual account (or exceeds `autoStripeAboveBytes`), the allocator slices the file into chunk-aligned segments (`64 MiB` default, always an exact multiple of `ZK.piece = 1 MiB`) and distributes them proportionally across all eligible accounts without exceeding any account's free quota.

---

## 3. On-Demand Streaming & Caching (`ContentReader` + `ChunkStore`)

- **1 MiB Chunk Addressing**: Logical byte reads `(offset, length)` are translated into `1 MiB` (`1,048,576`-byte) chunk indices.
- **SingleFlight Deduplication**: Concurrent reads for the same `(nodeId, versionId, chunkIndex)` coalesce into a single network range request via `SingleFlight`.
- **LRU Disk Cache + KeepList**: `ChunkStore` maintains a bounded on-disk cache of downloaded chunks and evicts least-recently-used chunks while protecting any file or folder pinned in `KeepList` for offline access.

---

## 4. Zero-Knowledge Cryptography (`OrbitCore.ZK`)

Helium implements an authenticated client-side encryption layer (`LockedRemote` + `ZK`):
- **Master Key & Key Derivation**: A 32-byte Master Key (`MK`) is used with `HKDF<SHA256>` and domain-separated info strings to derive independent 256-bit keys for key wrapping, filename encryption, filename HMAC, canary verification, and share links.
- **Chunk Encryption (`lockPiece` / `unlockPiece`)**:
  - Plaintext files are split into `1 MiB` pieces.
  - Each piece is sealed with `AES.GCM.seal` using a per-file 256-bit key (`FK`), a per-chunk 96-bit nonce (`fileNonce ^ chunkIndexBE64`), and Additional Authenticated Data (`AAD`) encoding the chunk index and whether it is the final chunk.
  - Each `1 MiB` plaintext piece produces `1,048,592` bytes (`1 MiB + 16-byte GCM authentication tag`), enabling exact byte-offset calculation for random-access HTTP `Range` requests on encrypted files.
