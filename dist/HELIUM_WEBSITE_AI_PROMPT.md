# Helium (`cogify.me/helium` / `cogify.me`) — Complete AI Website Prompt & Metadata Kit

> Paste the prompt and metadata below into **v0, Lovable, Bolt, Claude, Cursor, or ChatGPT** to generate a complete, high-converting macOS product landing page with the exact editorial layout, typography, color palette, and interactive showcase structure of `https://cogify.me/helium`.

---

## Copy-Paste AI Prompt

```markdown
Build a complete, production-ready marketing landing page for **Helium** (macOS app v0.0.1, built with ❤️ by cogify.me — connect@cogify.me), modeled on the minimalist editorial aesthetic and section structure of https://cogify.me/helium.

### 1. Visual Aesthetic & Design Tokens (Strictly Match Reference)
- **Background Palette**:
  - Primary Page Background: Warm alabaster off-white `#F7F7F7` (`rgb(247, 247, 247)`)
  - Elevated Card / Window Surface: Pure crisp white `#FFFFFF` with `1px solid #E5E5E3` border and soft ambient shadow `0 18px 50px rgba(0, 0, 0, 0.05)`
  - Highlight Word Pill Background: Soft warm gray `#E7E7E5` (`border-radius: 10px`, `padding: 2px 10px`) used behind key words in headlines (e.g., `[ zero ]`, `[ unlimited ]`, `[ 4 ]`)
  - Primary Ink / Headline: `#121212`
  - Secondary Body Copy: `#424240`
  - Muted / Step Number Copy: `#80807E`
  - Primary CTA Button: Solid `#111111` pill (`border-radius: 9999px`) with `#FFFFFF` text (` download for mac`)
- **Typography & Editorial Voice**:
  - Font Family: `-apple-system, BlinkMacSystemFont, "SF Pro Display", "Inter", sans-serif`
  - Monospace Step Numbers (`01`, `02`, `03`): `"SF Mono", "JetBrains Mono", monospace` (`font-variant-numeric: tabular-nums`)
  - **All-lowercase editorial copywriting**: Every headline, nav link, numbered step, and feature item is written in clean lowercase (except proper macOS paths like `/Volumes/Helium`, `Macintosh HD`, or shortcut `⌃⌥O`).
  - Headlines use tight negative tracking (`letter-spacing: -0.035em`, `line-height: 1.04`, `font-weight: 700`), with occasional italic serif/sans emphasis on a single word (e.g., `meet *helium*.`, `built for *every* kind of work.`, `stop deleting files to make *space*.`).

### 2. Core Product Metadata
- **App Name**: Helium (`helium`)
- **Version**: `0.0.1` (Build `1`)
- **Bundle ID**: `com.cogify.me/helium`
- **Creator**: `cogify.me` (`connect@cogify.me`)
- **Download Link**: `/Helium.dmg` (Apple Developer ID signed & notarized universal macOS installer)
- **System Requirements**: macOS 15.4+ / macOS 26 Tahoe
- **Logo / Mascot**: A friendly black folder icon with two white eyes and a happy smile (`HeliumIcon.png` / `HeliumMascot.png`), sitting on a white squircle.
- **Core Value Proposition**:
  Helium mounts a real local drive at `/Volumes/Helium` in macOS Finder that pools **N linked Google Drive accounts** into one unified cloud volume. Files show their full size and open immediately in any macOS app (`Preview`, `QuickTime`, `DaVinci Resolve`, `Final Cut Pro`, `DiskImageMounter`), while using **Zero bytes on disk** (`0 B on disk`) on your Mac's internal SSD.

### 3. Page Architecture & Section-by-Section Content (Modeled on cogify.me/helium)

#### Section 0: Floating Pill Navigation Bar (Sticky Top Center)
- Floating translucent white pill (`backdrop-filter: blur(16px)`, `background: rgba(255,255,255,0.88)`, `border: 1px solid #E6E6E4`, `border-radius: 9999px`)
- Links: `helium` · `how it works` · `drive pool` · `love` · `pricing` · `faq` · `download`

#### Section 1: Hero + Interactive macOS Finder & "Get Info" Mockup
- **Headline**: `meet` *`helium.`*
- **Subheadline**: `[ unlimited pooled space ]` `for your mac, without buying a new ssd.`
- **Primary CTA**: `[  download for mac ]` (`href="/Helium.dmg"`)
- **Meta Microcopy**: `free to download · apple notarized · end-to-end encrypted · multi-google-drive pool`
- **Interactive Hero Visual**:
  - A realistic macOS Finder window showing `Locations` in the sidebar: `Macintosh HD` and `Helium (11 TB)`.
  - Inside `Helium › Google Drive Pool`, show large media & disk image files (`wedding-film_final.mov — 48.2 GB`, `drone-coast_4k.mp4 — 21.7 GB`, `arduino-ide_2.3.10_macOS_arm64.dmg — 195.2 MB`, `Brand Shoot.psd — 2.3 GB`) each with a green badge `0 B on disk`.
  - Floating beside it, render a macOS **Get Info** inspector window for `wedding-film_final.mov` (`48.2 GB`) highlighting:
    `Size: 48,213,574,021 bytes (`**`[ Zero bytes on disk ]`**`)`
    `Where: /Volumes/Helium › Google Drive Pool`

#### Section 2: Role-Based Interactive Showcase ("built for *every* kind of work.")
- **Headline**: `built for` *`every`* `kind of work.`
- **Subheadline**: `pooled across your google drives, open in a second.`
- **Interactive Tab Pills**: `everyone` · `video editors` · `photographers` · `music makers` · `designers` · `developers`
  - **everyone**: macOS System Settings › Storage view showing `Macintosh HD` with plenty of free space and `helium — 11 TB pooled across 2 Google Drives · 0 KB on this Mac`.
  - **video editors**: 4K ProRes timeline (`wedding-film_final.mov 38.6 GB`, `drone-coast_4k.mp4 12.4 GB`) with badge `streaming from /Volumes/Helium`.
  - **photographers**: RAW photo catalog (`DSC_0412.ARW 48 MB · 6000×4000 RAW`) streaming directly from `/Volumes/Helium`.
  - **developers**: Mounting `.dmg` SDKs, Xcode archives, and LLM datasets straight from `/Volumes/Helium` with `0 B` local disk usage.

#### Section 3: Editorial Numbered Walkthrough (`1` through `4` — Exact Match to Reference Image)
- Centered single-column editorial layout (`max-width: 680px`):
  - **`[ 1 ]` `what it is`**
    - `a new drive in finder, powered by all your google drives combined.`
    - `it sits right next to macintosh hd at /Volumes/Helium. your files look and open like normal, in the apps you already use.`
    - `but they live in your pooled google drives, so a 50 GB film takes zero space on your mac.`
    - `and with optional zero-knowledge encryption, only you hold the key.`
  - **`[ 2 ]` `why it's different`**
    - `icloud and dropbox download the whole file before you can open it — and a single google drive caps out fast.`
    - `helium links unlimited google accounts into one storage pool and only streams the bytes you're using:`
    - 3 Stat Pills: **`0 bytes`** `used on your mac` · **`0.8 s`** `to open any file` · **`N × drives`** `pooled into 1 volume`
  - **`[ 3 ]` `how it works`**
    - `01` `install helium. link 1 or more google drives in your menu bar.`
    - `02` `open the /Volumes/Helium drive in finder.`
    - `03` `drag in your biggest files. done.`
  - **`[ 4 ]` `what you get`** (vertical list with minimalist line icons):
    - `combine unlimited google drives into one unified mac volume`
    - `end-to-end encrypted. only you hold the key`
    - `whole-file smart placement & cross-account segment striping`
    - `edit in davinci, final cut, imovie and capcut`
    - `ai tools like claude and chatgpt save right into helium`
    - `bi-directional sync between finder, cogify.me/helium & google drive web`
    - `undo a delete for 30 days with cloud recycle bin sync`
    - `keep folders or files on your mac to work offline`
    - `find any file across all drives with ⌃⌥O`
    - `drop files on the menu bar icon`
    - `uploads that don't slow your internet`
    - `big uploads pick up after wi-fi drops`
- **Large Editorial Statement Below List**:
  - **`your files in the cloud.`**
  - **`[ zero ]` `on your mac.`**
  - `helium looks like a normal drive. open a film or disk image and it plays right away, because your mac only grabs the part it needs.`
  - `nothing gets copied to your disk, so your mac keeps its space. delete something by mistake? you have 30 days in the helium recycle bin to get it back.`

#### Section 4: Multi-Account Google Drive Pool Deep Dive ("link multiple google drives. [ one massive drive ] in finder.")
- Interactive visual card illustrating Helium's **Storage Placement Engine**:
  - Shows a segmented capacity bar combining multiple Google accounts (`Account #1 Primary • 5.5 TB`, `Account #2 Overflow • 5.5 TB`, `Account #3 Free • 15 GB` = `11+ TB Total Pool`).
  - Explains the 2 placement modes:
    - **`01` `whole-file smart placement`**: Places complete files onto the highest-priority drive with enough free space so files can also be opened directly in Google Drive Web.
    - **`02` `cross-account segment striping`**: Automatically slices massive files (`256 MiB` segments) across multiple linked Google Drives when no single account has enough free space, and reassembles them transparently on the fly.
  - Highlights **1-Click Pool Rebalancer**, **SHA-256 Segment Integrity Verifier**, and **Safe Account Drain & Unlink**.

#### Section 5: Bento Feature Grid ("made for *big* files.")
- 6 clean white cards on the `#F7F7F7` canvas:
  1. **add your files**: `just drag them into /Volumes/Helium in finder or drop them onto the smiling helium icon in your menu bar.`
  2. **free up your mac**: `files live in your google drive pool as 0-byte APFS sparse placeholders, so your mac SSD stays free.`
  3. **open right away**: `double-click any video, PDF, image, or .dmg in finder — it opens directly in Preview, QuickTime, or DiskImageMounter without popping up extra windows.`
  4. **use files without wi-fi**: `click the pin icon or right-click any file to keep it offline on your mac, and unpin anytime in 1 click to reclaim space.`
  5. **bi-directional cloud sync**: `upload or delete in finder, the helium files manager, or google drive web — pool capacity, file breakdowns, and the 30-day recycle bin stay in sync.`
  6. **only you hold the key**: `turn on zero-knowledge AES-256-GCM encryption so filenames and segments are locked on your mac before they ever touch google drive.`

#### Section 6: Comparison Table ("why *helium*?")
- Compare **helium** vs **icloud drive** vs **google drive app** vs **dropbox**:
  - `combines multiple google accounts into one drive`: **helium: ✓** | others: ✕
  - `opens big files without taking space on your mac`: **helium: ✓ (0 B on disk)** | others: downloads to disk
  - `splits huge files across drives automatically`: **helium: ✓** | others: ✕
  - `real local volume in /Volumes/Helium`: **helium: ✓** | others: partly
  - `optional client-side zero-knowledge encryption`: **helium: ✓** | others: ✕

#### Section 7: FAQ Accordion ("questions, *answered*.")
- Include expandable lowercase Q&A items covering:
  - `what is helium?`
  - `how does multi-google-drive pooling work?`
  - `how can a file open in preview or quicktime if it uses 0 bytes on my mac?`
  - `what happens when i delete a file in finder or google drive?`
  - `are my google credentials and files safe?`
  - `what are the system requirements?`

#### Section 8: Footer CTA ("stop deleting files to make *space*.")
- Headline: `stop deleting files to make` *`space.`*
- Subheadline: `pool your google drives into /Volumes/Helium, today.`
- CTA Button: `[  download for mac (v0.0.1) ]` (`href="/Helium.dmg"`)
- Footer credit: `© 2026 helium · made with ❤️ by cogify.me (connect@cogify.me)`
```
