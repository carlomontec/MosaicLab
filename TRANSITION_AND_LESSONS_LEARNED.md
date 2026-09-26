# Transition from MacOSaiX & Lessons Learned 📘

This document captures the historical background, architectural evolution, and key lessons learned during the transition from the legacy **MacOSaiX** revival into the independent **MosaicLab** project.

---

## 1. The Origin: Frank Midgley's MacOSaiX (2002–2009)

*MacOSaiX* was originally created by **Frank M. Midgley** between 2002 and 2009 as an open-source photomosaic generator for Mac OS X (10.2–10.5). It introduced:
- Interlocking cubic Bézier jigsaw puzzle tessellations.
- Hexagonal honeycombs.
- Riemersma perceptual color weighting.
- An intuitive 2-pane Cocoa interface with an interactive blend slider.

Over two decades, computing shifted: 32-bit PowerPC/Intel architectures were replaced by 64-bit Apple Silicon, Objective-C/Cocoa gave way to Swift/SwiftUI, and image formats expanded from JPEG/TIFF to hardware-accelerated HEIC, AVIF, and WebP.

---

## 2. The Architectural Fork Dilemma & Separation Strategy

### Why Forking Was Problematic for a Modern Flagship:
1. **GitHub Network Baggage & Permanent Fork Banner**:
   - A GitHub repository created via the "Fork" button permanently displays `forked from <original>` in its header.
   - It cannot be detached without contacting GitHub Support, and its network graph remains tied to an obsolete 20-year-old codebase.
2. **Legacy Code & Distribution Readiness**:
   - The original codebase contained legacy ProjectBuilder (`.pbproj`) files, archaic frameworks, and mixed-license historical code not suitable for a clean, modern release on the Mac App Store or iOS/iPadOS App Store.
3. **Philosophical Conflict (Archival Tribute vs. Cutting-Edge Tool)**:
   - Retro-Mac enthusiasts want an authentic, unmarketed, faithful preservation of Frank Midgley's original software.
   - A modern tool needs cutting-edge computational vision, pure Swift architecture, multi-platform support, and modern branding.

### The Two-Repository Solution:
We cleanly divided the work into two dedicated repositories:

| Dimension | Archival Revival: `MacOSaiX_Remake` | Modern Flagship: `MosaicLab` |
| :--- | :--- | :--- |
| **Repository** | [`carlomontec/MacOSaiX_Remake`](https://github.com/carlomontec/MacOSaiX_Remake) | [`carlomontec/MosaicLab`](https://github.com/carlomontec/MosaicLab) |
| **Relationship** | Fork of original repo | **100% Standalone** (`isFork: false`) |
| **Target Version** | Preserved at revival commit (`f0a89e2`) | Starts fresh at **`v0.1.0`** |
| **Legacy Code** | Preserves original C/Obj-C math | **Zero legacy code** (100% pure Swift) |
| **Marketing & Tone**| Strictly unmarketed, respectful tribute to Frank Midgley | Technical, engineering-focused, edge-algorithm tool |
| **CLI Target** | Removed (authentic GUI preservation only) | Retained as headless **`mosaiclab-cli`** |
| **App Name** | `MacOSaiX Remake.app` | `MosaicLab.app` |
| **Document Format**| `.macosaix` | `.mosaiclab` |

---

## 3. Engineering & Code Modernization

In `MosaicLab`, 100% of the active codebase was rewritten in native Swift (`MosaicLabKit`), eliminating all legacy Objective-C dependencies:

1. **Native Vector Geometry (`TileGeometry.swift`)**:
   - Modern pure-Swift tessellations: classic uniform rectangular grid and adaptive multi-scale quadtrees (legacy hexagonal honeycombs and Bézier puzzle pieces stripped).
   - Adaptive **Quadtree Multi-Scale Decomposition**:
     - *Julia Extrema Range*: Homogeneity test (`max - min < threshold`) inspired by `ImageSegmentation.jl`.
     - *RGB Chebyshev Range*: Multi-channel color divergence isolating chromatic boundaries without area dilution.
     - *$O(1)$ Summed-Area Table (SAT) Variance*: Constant-time local standard deviation via Crow (1984) Integral Images.
     - *2:1 Topological Neighbor Balancing*: Enforces that adjacent quadtree cells differ by at most one subdivision level.
     - *Whole Canvas Mode*: Single top-down root decomposition for macro compositions.
2. **Edge-Aware Directional Matching (`TileMatcher.swift`)**:
   - 3×3 Sobel convolution operators for gradient vector extraction.
   - Bilinear angular interpolation into $L_2$-normalized 8-bin gradient orientation histograms (HOG).
   - Saliency-gated angular distance matching to preserve contours, strokes, and line flow.
3. **Perceptual Color Science (`ColorTransfer.swift`)**:
   - Statistical palette distribution shifting in perceptual **OKLab** color space (Reinhard et al. 2001), adjusting candidate hue/chroma to match target regions while preserving internal photo contrast and sharpness.
4. **Massive Media Pipeline**:
   - Two-stage in-memory candidate store (`~1 KB` thumbnails and descriptors) enabling $<5\text{ ms}$ exhaustive scans over 10,000+ photos without disk I/O.
   - Direct hardware ImageIO decoding for `.heic`, `.hif` (Sony/Canon/Nikon), `.avif`, `.webp`, `.png`, and `.jpeg`.
   - PhotoKit integration for direct pooling from Apple Photos albums.
5. **Clean Identifier Sanitization**:
   - All legacy identifiers were renamed: `MacOSaiXKit` $\to$ `MosaicLabKit`, `MacOSaiXTile` $\to$ `MosaicTile`, `MacOSaiXMatcher` $\to$ `MosaicMatcher`, `macosaix-cli` $\to$ `mosaiclab-cli`.

---

## 4. Key Lessons Learned

### Lesson 1: Communication & Copy Tone (Engineering-Minded)
- Carlo Monjaraz-Tec holds a PhD in engineering.
- **Avoid Corporate Marketing Hype**: Phrases like *"revolutionary cutting-edge computational photography lab studio powerhouse"* sound artificial and sloppy.
- **Adopt an Understated, Technically Precise Tone**: Explain the mathematical criteria clearly (e.g., *2:1 topological balancing, Chebyshev color divergence, OKLab distribution shifting*).
- **Core Mood**: A powerful tool built on edge algorithms, available for users to achieve high quality and have fun exploring creative ideas.

### Lesson 2: Git & Version Control Protocols (Universal)
- **NEVER run `git commit` or `git push` without explicit, unambiguous user confirmation.** Always prepare changes, explain diffs, and ask first.
- **Explicit File Staging Only**: Never run blanket `git add .` or `git add -A`. Explicitly specify target files (`git add path/to/file`), and verify with `git status`.
- **Branch Naming Convention**: Always use `main` as the default primary branch across all repositories. Never use `master` (it carries obsolete colonialist references).

### Lesson 3: Inspiration Framing vs. Derivative Framing
- When modernizing classic or legacy software, refer to the original software strictly as an **inspiration**, never as "based on it", "a remake of it", or "a fork".
- In commit messages and documentation, frame changes around native modern architecture, performance, and cross-platform design without referencing legacy copyright removals.

### Lesson 4: High-Performance Matching & Thread Architecture on Apple Silicon
- **32-Bit Arithmetic Prevents Overflow Traps**: In pixel delta calculations, squared difference values ($255^2 = 65,025$) overflow signed 16-bit integers (`Int16.max = 32,767`), causing Swift checked-arithmetic `EXC_BREAKPOINT` traps. Always use 32-bit integer arithmetic (`Int32`) for SIMD pixel math.
- **Thread Safety on Swift `Data`**: Concurrently accessing `Data.withUnsafeBytes` across threads in `DispatchQueue.concurrentPerform` induces ARC retain/release collisions on the underlying `_DataStorage` object (`(Data Abort)`). Pre-extract raw immutable `[UInt8]` byte arrays into `Sendable` structs prior to concurrent execution.
- **Mathematical Pruning (Jensen's Inequality)**: Hoist metric dispatch out of inner loops and use mathematical lower bounds ($(\bar{R}_1 - \bar{R}_2)^2 + (\bar{G}_1 - \bar{G}_2)^2 + (\bar{B}_1 - \bar{B}_2)^2 \ge S_{\text{best}}$) to skip 70–90% of redundant pixel comparisons early.
- **The ImageIO Decoding Illusion**: Vectorized 16×16 SIMD matching across 1,000 tiles runs in ~2–4 ms. Synchronous 256px ImageIO decoding (~150–300 ms) in the same loop completely eclipses the multi-core math, making Activity Monitor appear single-threaded (~12% load). Never perform heavy synchronous image decoding inside the candidate matching loop.
- **Main Thread Event Loop Starvation & Beachballing**: Calling heavy offscreen canvas re-renders (`draw(_:)` across 1,000 tiles) at high frequencies (e.g. 12 Hz) freezes the macOS WindowServer event pump, causing spinning beachballs and ignoring Dock activation clicks. Decouple lightweight numerical progress (~10 Hz) from visual canvas redraws (1.5s interval) to keep the UI 100% responsive.

### Lesson 5: Multi-Agent Workspace Isolation
- When multiple AI coding agents operate concurrently on the same codebase, branch mixing can occur if both operate in the same working tree.
- Keep agent branches isolated using separate Git worktrees (`git worktree add`) or strictly coordinated explicit file staging to avoid cross-contamination of unrelated features.

---

## 5. Current Handover State

- **`MosaicLab` Repository**: Initial release `v0.1.0` is published and live at [github.com/carlomontec/MosaicLab](https://github.com/carlomontec/MosaicLab).
- **Local Directory**: `/Users/carlo/code/Proj_MosaicLab/MosaicLab`.
- **Branch**: `feature/multiplatform-phase1`
- **Accomplishments in this Sprint**:
  - Implemented multi-core SIMD integer matching with Jensen's inequality early pruning.
  - Eliminated synchronous thumbnail preheating and solved the single-core stall (reaching 150%+ multi-core CPU peaks).
  - Paced canvas redraws to 1.5s, eliminating beachballs and restoring instant Dock/window responsiveness.
  - Added completion notifications and audio chimes via `UserNotifications`.
  - Documented Cubehelix match quality heatmaps and image-banning in `IDEAS.md`.
- **Immediate Next Focus**:
  - Designing a custom **Application Icon (`AppIcon.icns`)** and **Document Icon (`.mosaiclab`)** for `MosaicLab` (to be conducted in the next pair-programming session).
