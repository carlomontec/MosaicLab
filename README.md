# MosaicLab

<p align="center">
  <img src="docs/screenshot.png" alt="MosaicLab in Action" width="850">
</p>

<p align="center">
  <strong>A native macOS application and command-line tool for creating high-resolution photomosaics using modern image processing algorithms.</strong><br>
  Engineered by <strong>Carlo Monjaraz-Tec</strong> (2026). Inspired by classic Mac software <em>MacOSaiX</em> by Frank M. Midgley.
</p>

<p align="center">
  <a href="MANUAL.md"><strong>📖 User Manual & Algorithmic Handbook</strong></a> |
  <a href="#quick-start"><strong>🚀 Quick Start</strong></a> |
  <a href="#core-algorithms--features"><strong>⚙️ Algorithms</strong></a> |
  <a href="#command-line-interface-cli"><strong>💻 CLI</strong></a>
</p>

---

## Overview

**MosaicLab** is a native macOS tool for generating photomosaics using modern computer vision and image processing algorithms. It combines multi-scale quadtree decomposition, edge-aware directional matching, and perceptual color transfer into an interactive desktop application and headless CLI—designed for both creative experimentation and large-scale, high-resolution printing.

---

## Core Algorithms & Features

### 🔲 Adaptive Multi-Resolution Quadtree Tiling
Instead of restricting the canvas to a uniform grid, MosaicLab can recursively subdivide regions based on local image complexity:
- **Julia Extrema Range**: Homogeneity test (`max - min < threshold`) inspired by `ImageSegmentation.jl`, isolating fine contours (eyes, lips, high-contrast borders) without area dilution.
- **RGB Color Range**: Multi-channel Chebyshev divergence test that captures chromatic boundaries even when luminance is identical.
- **$O(1)$ Summed-Area Table Variance**: Constant-time evaluation of local luminance standard deviation via Crow (1984) Integral Images.
- **2:1 Balanced Transitions**: Enforces that adjacent quadtree cells differ by at most one subdivision level, preventing harsh scale steps across tile boundaries.
- **Whole Canvas Mode**: Single top-down root decomposition for macro-scale compositions.

### 🧭 Edge-Aware Directional Matching (Sobel HOG)
To preserve the visual flow of lines, strokes, and contours:
- Evaluates local gradient vectors via 3×3 Sobel operators.
- Computes an $L_2$-normalized 8-bin gradient orientation histogram (HOG) with bilinear angular interpolation.
- Aligns candidate photo line flow with target contours using saliency-gated angular distance.

### 🎨 Color Science & Perceptual Matching
- **Riemersma Color Metric**: Weights RGB differences based on human eye spectral sensitivities rather than unweighted Euclidean distance.
- **Reinhard OKLab Color Transfer**: Statistical palette transfer in OKLab space (Reinhard et al. 2001), shifting candidate color distributions toward target tiles while preserving internal image contrast.
- **Placement Controls**: Enforce single-use mode (`--max-reuse 1`) or space identical photos apart using minimum grid distance constraints.

### 🧩 Geometric Tessellations
- **Jigsaw Puzzles (`puzzle`)**: Interlocking cubic Bézier tabs and sockets with configurable curviness and tab ratio parameters.
- **Hexagonal Honeycombs (`hex`)**: Hexagonal grid with coordinate clamping along canvas boundaries.
- **Classic Rectangles (`rect`)**: Uniform rectangular grid for classic photomosaics.

### ⚡ Native Performance & Media Pipeline
- **Modern Apple Stack**: Built with Swift, CoreGraphics, ImageIO, and PhotoKit targeting macOS and iPadOS/iOS.
- **Hardware-Accelerated Codecs**: Direct decoding for AVIF, HEIC/HEIF (with hardware EXIF rotation), WebP, JPEG, PNG, TIFF, and BMP.
- **Multi-Threaded Solver**: Parallel candidate matching across CPU cores using Swift Concurrency (`TaskGroup`).
- **Memory Safety Guard**: Pre-flight RAM verification bounds working memory to safely handle ultra-high-resolution 12,000+ pixel exports.
- **Source Pooling**: Simultaneously pool photos from Apple Photos albums and local file directories.

---

## Quick Start

### Building and Running the App

```bash
swift build -c release
bash scripts/bundle_app.sh
open "MosaicLab.app"
```

> [!NOTE]
> **Ad-Hoc Signing Notice**  
> If launching an ad-hoc signed build locally, macOS may require confirming the open dialog on first launch:
> ```bash
> xattr -cr "MosaicLab.app"
> ```

---

## Command-Line Interface (`cli`)

For automation, batch processing, and scripting:

### 1. Build
```bash
swift build -c release
```
The executable is located at `.build/release/mosaiclab-cli`.

### 2. Generate a Mosaic
```bash
.build/release/mosaiclab-cli \
  --target "~/Pictures/Sample.heic" \
  --sources "~/Pictures/Photos" \
  --shape quadtree \
  --quadtree-algo whole \
  --quadtree-depth 4 \
  --quadtree-thresh 0.15 \
  --quadtree-min-tile 8 \
  --color-transfer 0.30 \
  --output "~/Desktop/mosaic.png"
```

*For complete flag descriptions and parameter recipes, see the [User Manual](MANUAL.md).*

---

## Project Structure

```
MosaicLab/
├── MosaicLab.app/           # Bundled macOS application
├── Package.swift            # Swift Package manifest
├── MANUAL.md                # User manual & algorithmic details
├── README.md                # Project overview
├── docs/                    # Screenshots and assets
├── scripts/                 # App bundle packaging scripts
└── Sources/
    ├── MosaicLabKit/        # Computational engine, geometry, matcher, PhotoKit
    ├── MosaicLabApp/        # SwiftUI desktop application
    └── mosaiclab-cli/       # Command-line tool
```

---

## Background & Inspiration

**MosaicLab** was inspired by *MacOSaiX*, a classic Mac OS X application created by **Frank M. Midgley** (2002–2007). 

MosaicLab is a native implementation built using modern macOS technologies (Swift, CoreGraphics, ImageIO, and PhotoKit), extending classical mosaic generation with multi-scale quadtree decomposition, edge-aware matching, and perceptual color science.
