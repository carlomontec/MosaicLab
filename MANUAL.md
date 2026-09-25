# MosaicLab — User Manual & Algorithmic Handbook

<p align="center">
  <img src="docs/screenshot.png" alt="MosaicLab GUI" width="850">
</p>

Welcome to the definitive user manual and algorithmic reference for **MosaicLab** — the modern Apple Silicon revival of Frank M. Midgley's legendary Mac OS X photomosaic application.

This handbook covers everything from everyday graphical workflows and keyboard shortcuts to in-depth mathematical formulations of adaptive quadtree segmentation, OKLab color transfer, and edge-aware directional matching.

---

## Table of Contents

1. [System Architecture & Capabilities](#1-system-architecture--capabilities)
2. [Graphical User Interface (GUI) Guide](#2-graphical-user-interface-gui-guide)
   - [Window Overview & Toolbar](#window-overview--toolbar)
   - [Step 1: Selecting a Target Image](#step-1-selecting-a-target-image)
   - [Step 2: Configuring Photo Sources](#step-2-configuring-photo-sources)
   - [Step 3: Choosing Tile Shapes & Tessellations](#step-3-choosing-tile-shapes--tessellations)
   - [Step 4: Color Matching & Perceptual Controls](#step-4-color-matching--perceptual-controls)
   - [Step 5: Solving, Pausing & Real-Time Navigation](#step-5-solving-pausing--real-time-navigation)
   - [Step 6: Saving Projects & High-Resolution Export](#step-6-saving-projects--high-resolution-export)
3. [Adaptive Quadtree Segmentation (Deep Dive)](#3-adaptive-quadtree-segmentation-deep-dive)
   - [The Quadtree Concept](#the-quadtree-concept)
   - [Algorithm 1: Whole Canvas Quadtree](#algorithm-1-whole-canvas-quadtree)
   - [Algorithm 2: Julia Extrema Range](#algorithm-2-julia-extrema-range)
   - [Algorithm 3: RGB Color Range](#algorithm-3-rgb-color-range)
   - [Algorithm 4: Variance / Hybrid](#algorithm-4-variance--hybrid)
   - [Quadtree Control Parameters](#quadtree-control-parameters)
4. [Geometric Tile Shapes](#4-geometric-tile-shapes)
   - [Uniform Rectangles](#uniform-rectangles)
   - [Adaptive Quadtrees](#adaptive-quadtrees)
5. [Advanced Perceptual Color & Matching Science](#5-advanced-perceptual-color--matching-science)
   - [Riemersma Spectral Color Metric](#riemersma-spectral-color-metric)
   - [Reinhard Statistical Color Transfer in OKLab Space](#reinhard-statistical-color-transfer-in-oklab-space)
   - [Edge-Aware Directional Matching (Sobel HOG)](#edge-aware-directional-matching-sobel-hog)
   - [Placement Constraints: Max Reuse & Min Distance](#placement-constraints-max-reuse--min-distance)
6. [Command-Line Interface (`mosaiclab-cli`)](#6-command-line-interface-mosaiclab-cli)
   - [Building & Installing](#building--installing)
   - [Complete Flag Reference](#complete-flag-reference)
   - [Ready-to-Use Recipes](#ready-to-use-recipes)
7. [Keyboard Shortcuts & Pro Tips](#7-keyboard-shortcuts--pro-tips)

---

## 1. System Architecture & Capabilities

MosaicLab is engineered from the ground up for modern macOS (macOS 14 Sonoma, macOS 15 Sequoia, and newer) on Apple Silicon (M1/M2/M3/M4):

- **Zero UI Freezes**: Target subsampling, tile mask rasterization, and source image evaluation run asynchronously in detached background worker tasks (`Task.detached`), leaving the AppKit/SwiftUI runloop completely unhindered at 60–120 FPS.
- **Hardware-Accelerated Codecs**: Utilizes Apple's native `ImageIO` framework to read and export modern file formats including **AVIF**, **HEIC/HEIF** (with full hardware EXIF orientation handling), **WebP**, JPEG, PNG, TIFF, and BMP.
- **Safe Memory Architecture**: All 10-bit / HDR surfaces and color-managed images are normalized to contiguous 8-bit sRGB buffers before processing, preventing kernel faults or GPU out-of-memory crashes.
- **Progressive Live Assembly**: Watch tiles refine and update on the fly as better matching photos are discovered.

> [!NOTE]
> **Ad-Hoc Signing & First Launch on macOS**:  
> Because MosaicLab is a free community open-source project without a paid Apple Developer subscription (\$99/year), macOS Gatekeeper may show a standard prompt on first launch. To permit launch, simply **right-click `MosaicLab.app` in Finder $\to$ Open $\to$ Open**, or click **Open Anyway** in **System Settings $\to$ Privacy & Security**.

---

## 2. Graphical User Interface (GUI) Guide

```
+-----------------------------------------------------------------------------------+
| [Folder] [Save] [Info]    Status: Ready (124 photos matched)    [Export]  [▶ Start] [■] |
+-------------------------------+---------------------------------------------------+
|  SIDEBAR CONTROLS             |  INTERACTIVE MOSAIC CANVAS                        |
|                               |                                                   |
|  1. Target Image              |  [ Pan with 2 fingers / Space+Drag ]              |
|     [Choose Image...]         |  [ Pinch to zoom 25% - 400% ]                     |
|                               |                                                   |
|  2. Photo Sources             |                                                   |
|     [Drag & drop folders]     |                                                   |
|                               |                                                   |
|  3. Tile Shapes               |                                                   |
|     (Adaptive Quadtree)       |                                                   |
|     - Algorithm Picker        |                                                   |
|     - Sensitivity Slider      |                                                   |
|     - Min Tile Floor          |                                                   |
|                               |                                                   |
|  4. Matching Options          |  [Original <===========|===========> Mosaic]      |
|     - Color Transfer Slider   |                                                   |
|     - Edge Alignment Slider   |                                                   |
+-------------------------------+---------------------------------------------------+
```

### Window Overview & Toolbar

- **Dock Icon & Window Drag-and-Drop**:
  - Drag any `.mosaiclab` project file onto the app icon in the macOS Dock or directly into the main window to open the project.
  - Drag any image file directly onto the canvas to set it as the basis target image.
- **Top Left**:
  - **Open Project (`⌘O`)**: Open a previously saved `.mosaiclab` project package.
  - **Save Project (`⌘S`)**: Save the current mosaic setup, source directories, and matched tiles.
  - **About (`ⓘ`)**: View version info, credits, and links.
- **Center**:
  - **Status Capsule**: Displays active solver status, match counts, and progress spinners.
- **Top Right**:
  - **Export (`⌘E`)**: Open high-resolution export dialog.
  - **Start / Pause (`⌘R`)**: Begin or pause candidate evaluation.
  - **Stop (`⌘.`)**: Finalize and stop matching.

### Step 1: Selecting a Target Image

Click **Choose Image...** in Section 1 of the sidebar, or **drag an image directly onto the mosaic canvas**, to select the image your photomosaic will recreate.

> [!TIP]
> High-contrast images with well-defined subjects (portraits, architecture, distinctive objects, vehicles, landscapes) produce the most visually stunning photomosaics. Images with large blown-out white areas or pitch-black voids benefit most from our **Adaptive Quadtree** mode.

### Step 2: Configuring Photo Sources

Add folders containing photos that will serve as the constituent tiles:
- Click **Add Folder...** or **drag and drop folders directly from Finder** into the source list.
- All subfolders are automatically scanned recursively.
- Both standard formats (JPEG, PNG) and mobile formats (HEIC from iPhones, AVIF, WebP) are fully supported.

> [!NOTE]
> A source collection of **500 to 5,000+ photos** offers optimal color variety. However, with **Reinhard OKLab Color Transfer**, even small collections of 50–100 photos can produce remarkable results.

### Step 3: Choosing Tile Shapes & Tessellations

Select from two primary tessellation architectures:
1. **Rectangles / Squares**: Traditional uniform grid with configurable across/down density.
2. **Adaptive Quadtree**: Dynamic multi-resolution tiling that places small tiles in detailed regions and large tiles in homogeneous regions.

### Step 4: Color Matching & Perceptual Controls

- **Color Metric**:
  - *Riemersma (Perceptual)*: Human eye spectral sensitivity weighting.
  - *Euclidean (RGB)*: Mathematical RGB channel distance.
- **Max Reuse**:
  - Set to `1` for a strict "No Duplicates" fine-art mosaic where every photo is unique.
  - Set to `0` (or leave unchecked) for unlimited reuse.
- **Minimum Distance**:
  - Restricts identical photos from appearing within $N$ tiles of each other.
- **Reinhard OKLab Color Transfer**:
  - Adjust slider from `0%` (pure original photo colors) to `100%` (complete color match).
  - Recommended sweet spot: `30% – 50%`.
- **Edge-Aware Directional Matching**:
  - Aligns internal photo contours with the target image edges.
  - Recommended sweet spot: `25% – 45%`.

### Step 5: Solving, Pausing & Real-Time Navigation

- Click **Start** (`⌘R`) at the top right to begin matching.
- **2D Glide & Momentum**: Drag with two fingers on your trackpad to glide across the canvas with native macOS inertia.
- **Pinch-to-Zoom**: Pinch on the trackpad or hold `⌘` and scroll to zoom smoothly between `25%` and `400%`.
- **Compare Slider**: Drag the blend slider at the bottom of the canvas to seamlessly crossfade between the original target photo and the assembled mosaic.
- **Tile Inspection & Substitution**:
  - Click any tile on the preview canvas to open its detail inspector popover.
  - **Find Substitute (`arrow.triangle.2.circlepath`)**: Recomputes candidate scores for that specific tile across all source photos, excluding the current photo. Clicking it repeatedly cycles through the 2nd best, 3rd best, 4th best candidates, updating the canvas in real time.
  - **Choose Photo... (`photo.badge.plus`)**: Manually select any image from disk to place in this tile.
  - **Reveal in Finder (`folder`)**: Selects and highlights the original constituent image in Finder.

### Step 6: Saving Projects & High-Resolution Export

- **Saving (`⌘S`)**: Saves a lightweight `.mosaiclab` package containing image bookmarks, settings, and tile state.
- **Exporting (`⌘E`)**:
  - Choose output format: **PNG**, **JPEG**, **TIFF**, **HEIC**, or **AVIF**.
  - Choose resolution: `1×` (Preview), `2×` (Retina), `4×` (Ultra HD / Print), or specify custom pixel width up to 12,000+ pixels.
  - Toggle and customize border cutlines (width and color: black, white, or clear).

---

## 3. Adaptive Quadtree Segmentation (Deep Dive)

### The Quadtree Concept

Traditional photomosaics force an unpleasant compromise:
- **Small tiles** capture fine facial details (eyes, lips, eyelashes) but make individual photos tiny and unreadable.
- **Large tiles** showcase your photos beautifully, but destroy delicate contours into jagged pixel blocks.

**Adaptive Quadtree Segmentation** solves this by decomposing the canvas into a hierarchical tree: smooth areas remain large, while intricate features automatically subdivide into progressively smaller tiles.

```
+-------------------------------+-------------------------------+
|                               |               |       |   |   |
|                               |               |-------+-------|
|                               |               |   |   |       |
|          LARGE TILE           +---------------+---------------+
|          (Sky / Flat)         |               |               |
|                               |               |               |
|                               |               |               |
+---------------+---------------+---------------+---------------+
|               |       |   |   |                               |
|               |-------+-------|                               |
|               |   |   |       |          LARGE TILE           |
+---------------+---------------+          (Background)         |
|               |               |                               |
|               |               |                               |
|               |               |                               |
+---------------+---------------+-------------------------------+
```

### Algorithm 1: Whole Canvas Quadtree

- **How it works**: Begins with a single root cell covering the **entire image canvas** ($0, 0, W, H$).
- **Behavior**: Recursively tests whether the entire rectangle is sufficiently uniform. If not, it splits into 4 quadrants. This produces a dramatic macro-composition where massive tiles frame large sky or background areas, while focal subjects are rendered with dense, intricate tiles.
- **Balancing**: Integrated with 2:1 neighbor balancing to guarantee no harsh visual steps between adjacent tiles.

### Algorithm 2: Julia Extrema Range

Inspired by Julia's `ImageSegmentation.jl` / `RegionTrees.jl`:

$$\Delta_{\text{extrema}} = \max_{(x,y) \in R} Y(x,y) - \min_{(x,y) \in R} Y(x,y)$$

A quadrant is considered homogeneous and stops subdividing if:

$$\Delta_{\text{extrema}} < \text{threshold}$$

- **Why it excels**: Unlike variance, which averages pixel differences over the entire quadrant, the extrema range is ultra-sensitive to razor-thin high-contrast features: a single-pixel line, an eyelash, or a bright reflection will immediately trigger subdivision.
- **Smooth areas**: Smooth gradients (e.g. skin tones, soft shadows) have low extrema ranges and remain gracefully large.

### Algorithm 3: RGB Color Range

Computes the Chebyshev color divergence across all three color channels simultaneously:

$$\Delta_{\text{RGB}} = \max \left( \Delta R, \Delta G, \Delta B \right)$$

where:

$$\Delta C = \max_{(x,y) \in R} C(x,y) - \min_{(x,y) \in R} C(x,y)$$

- **Why it excels**: Catches chromatic transitions where luminance is identical but hue or saturation shifts sharply (e.g. a red flower on green foliage of equal perceived brightness).

### Algorithm 4: Variance / Hybrid

Uses Crow (1984) Summed-Area Tables (Integral Images) to compute statistical variance $\sigma_Y$ in $O(1)$ constant time (8 lookups per quadrant), combined with Sobel gradient edge density:

$$\text{Detail} = (1 - \alpha) \cdot \frac{\|\nabla Y\|}{M_{\max}} + \alpha \cdot \frac{\sigma_Y}{128.0}$$

- **Detail Modes**:
  - *Edge-Aware ($\alpha = 0.2$)*: Focuses subdivision strictly along sharp contours.
  - *Balanced ($\alpha = 0.5$)*: Equal balance of edges and surface texture.
  - *Texture-Sensitive ($\alpha = 0.8$)*: Subdivides on high-frequency noise and fine textures.

### Quadtree Control Parameters

| Parameter | Range | Description |
| :--- | :--- | :--- |
| **Base Grid** | 10×10 to 80×80 | Starting coarse grid before adaptive subdivision (ignored in Whole Canvas mode). |
| **Max Depth** | 1 to 5 levels | Maximum subdivision depth ($2^D$ factor, up to $32\times$ smaller than base tiles). |
| **Detail Sensitivity** | 0% to 100% | Sensitivity slider. Calibrated so 0% (far left, threshold `0.85`) preserves large base tiles, while 100% (far right, threshold `0.05`) isolates subtle nuances. |
| **Min Tile Size Floor** | 4, 8, 16, 24, 32, 48 px | Absolute hardware floor preventing tiles from becoming microscopic unreadable specs. |
| **2:1 Balanced Transitions**| On / Off | Restricts neighbor depth differences to $\le 1$ level, creating smooth aesthetic transitions. |

---

## 4. Geometric Tile Shapes

### Uniform Rectangles

The classic photomosaic layout. Maximizes photo area and visual clarity with uniform tile dimensions across the canvas. Fully configurable in horizontal (`--across`) and vertical (`--down`) counts.

### Adaptive Quadtrees

Dynamic multi-resolution hierarchical subdivision. Rather than applying a fixed uniform grid, the canvas is decomposed into quadtree quadrants according to mathematical homogeneity criteria:
- **Julia Range Extrema**: Isolates local luminance extremes ($L_{\max} - L_{\min}$).
- **RGB Chebyshev Range**: Evaluates multi-channel color divergence.
- **SAT Local Variance**: Constant-time variance evaluation via Summed-Area Tables.
- **Whole-Canvas vs. Grid-Seeded**: Supports global root subdivision or grid-cell multi-scale refinement.
- **2:1 Balanced Neighbor Constraints**: Ensures harmonious visual transitions with no adjacent cell differing by more than one scale step.

---

## 5. Advanced Perceptual Color & Matching Science

### Riemersma Spectral Color Metric

Traditional Euclidean distance in RGB space fails because human vision has non-uniform spectral sensitivities (we are much more sensitive to subtle differences in green than in blue):

$$\Delta C = \sqrt{2 \Delta R^2 + 4 \Delta G^2 + 3 \Delta B^2 + \frac{\bar{R}(\Delta R^2 - \Delta B^2)}{256}}$$

MosaicLab uses this perceptual metric by default, producing mosaics that look naturally photographic rather than digitally synthesized.

### Reinhard Statistical Color Transfer in OKLab Space

When your source photos don't match the target image's color palette, traditional software applies a crude transparent color overlay. This washes out contrast and muddies details.

Instead, MosaicLab implements **Reinhard Color Transfer in the modern OKLab space**:
1. Candidate and target tile pixels are mapped to linear OKLab coordinates ($L, a, b$).
2. Mean ($\mu$) and standard deviation ($\sigma$) are computed per channel.
3. Candidate pixel values are normalized and shifted:
   $$c_{\text{trans}} = \mu_{\text{target}, c} + \left( \frac{\sigma_{\text{target}, c}}{\sigma_{\text{src}, c}} \right) \cdot (c_{\text{src}} - \mu_{\text{src}, c})$$
4. The user controls transfer strength via an interactive real-time slider ($0\%$ to $100\%$). Lightness ($L$) and chromatic channels ($a, b$) are shifted without flattening shadow details.

### Edge-Aware Directional Matching (Sobel HOG)

Extracts an 8-bin Histogram of Oriented Gradients (HOG) from both the target tile and candidate photos. Photos whose internal line flow matches the target tile's edge direction receive a matching score bonus.

### Placement Constraints: Max Reuse & Min Distance

- **Max Reuse**: Restricts how many times any single source photo can appear in the mosaic. Setting this to `1` produces a 100% unique "No Duplicates" mosaic.
- **Min Distance**: Guarantees that duplicate photos are separated by at least $N$ tiles in Manhattan grid distance, preventing visual clustering.

---

## 6. Command-Line Interface (`mosaiclab-cli`)

For headless servers, automated scripts, and power users, the complete MacOSaiX engine is available via `mosaiclab-cli`.

### Building & Installing

```bash
cd macosaix-modern
swift build -c release
sudo cp .build/release/mosaiclab-cli /usr/local/bin/
```

### Complete Flag Reference

| Flag | Argument | Default | Description |
| :--- | :--- | :--- | :--- |
| `--target` | `<path>` | *Required* | Path to target image (AVIF, HEIC, PNG, JPEG, TIFF, WebP). |
| `--sources` | `<path>` | *Required* | Directory of source photos (recursively scanned). |
| `--output` | `<path>` | `mosaic.png` | Destination file path for rendered mosaic. |
| `--shape` | `rect` \| `quadtree` | `rect` | Tile geometry shape. |
| `--across` | `<int>` | `30` | Number of tiles horizontally (or base across for quadtree). |
| `--down` | `<int>` | `20` | Number of tiles vertically (or base down for quadtree). |
| `--quadtree-algo` | `whole` \| `julia` \| `color` \| `variance` | `julia` | Quadtree segmentation algorithm. |
| `--quadtree-depth`| `1` – `5` | `3` | Maximum quadtree subdivision levels. |
| `--quadtree-thresh`| `0.02` – `0.85` | `0.15` | Detail sensitivity threshold (lower = more subdivisions). |
| `--quadtree-min-tile`| `<pixels>` | `16` | Minimum tile dimension floor in pixels. |
| `--quadtree-balance`| `true` \| `false` | `true` | Enforce 2:1 balanced transitions. |
| `--quadtree-mode` | `edge` \| `balanced` \| `texture` | `balanced` | Detail weighting mode for variance algorithm. |
| `--color-transfer`| `0.0` – `1.0` | `0.0` | Reinhard OKLab color transfer strength. |
| `--edge-weight` | `0.0` – `1.0` | `0.0` | Edge-aware directional matching weight. |
| `--max-reuse` | `<int>` | `0` | Max appearances per photo (`0` = unlimited, `1` = unique). |
| `--min-distance` | `<int>` | `2` | Minimum grid distance between duplicate photos. |
| `--metric` | `riemersma` \| `rgb` | `riemersma` | Perceptual or Euclidean color metric. |
| `--width` | `<pixels>` | `2400` | Final mosaic render width in pixels. |
| `--stroke` | `<pixels>` | `0.0` | Border outline stroke width. |
| `--stroke-color`| `black` \| `white` | `black` | Border outline stroke color. |
| `--force` | *None* | *Off* | Bypass physical RAM safety guard. |

### Ready-to-Use Recipes

#### Whole-Canvas Adaptive Masterpiece
```bash
mosaiclab-cli \
  --target portrait.heic \
  --sources ~/Pictures/FamilyPhotos \
  --shape quadtree \
  --quadtree-algo whole \
  --quadtree-depth 4 \
  --quadtree-thresh 0.15 \
  --quadtree-min-tile 8 \
  --color-transfer 0.35 \
  --output portrait_adaptive.png
```

#### High-Fidelity Edge-Aligned Uniform Grid (Print 6000px)
```bash
mosaiclab-cli \
  --target landscape.jpg \
  --sources ~/Pictures/Nature \
  --shape rect \
  --across 60 \
  --down 40 \
  --edge-weight 0.3 \
  --color-transfer 0.2 \
  --width 6000 \
  --output landscape_print.png
```

#### Unique "No Duplicates" Classic Mosaic
```bash
mosaiclab-cli \
  --target artwork.png \
  --sources ~/Pictures/CameraRoll \
  --shape rect \
  --across 45 \
  --down 30 \
  --max-reuse 1 \
  --output artwork_unique.png
```

---

## 7. Keyboard Shortcuts & Pro Tips

### Keyboard Shortcuts

| Shortcut | Action | Scope |
| :--- | :--- | :--- |
| `⌘O` | Open Project | Global |
| `⌘S` | Save Project | Global |
| `⌘E` | Export Mosaic Image | Global |
| `⌘R` | Start / Pause Matching | Global |
| `⌘.` | Stop Matching | Global |
| `Space + Drag` | Pan Mosaic Canvas | Canvas |
| `⌘ + Scroll Wheel` | Zoom In / Out | Canvas |
| `Two-finger Pinch` | Fluid Trackpad Zoom | Canvas |

### Pro Tips for Best Results

1. **Optimal Photo Library**: Aim for at least 500 diverse photos. When working with themed libraries (e.g. all black-and-white or all underwater photos), set **Color Transfer** to `40%–50%` to bridge color gaps naturally.
2. **Preventing Duplicates**: If your library has 3,000+ photos, set **Max Reuse** to `1`. Every tile will be a completely distinct memory.
3. **Print Resolution**: For a 24" × 36" poster at 300 DPI, export with `--width 7200` or choose `4×` scaling in the GUI export sheet.
4. **Adaptive Sensitivity**:
   - For bold subjects with stark skies: Use **Whole Canvas Quadtree** with `Sensitivity: 15%–20%` and `Min Tile: 8px`.
   - For intricate text or micro-patterns: Use **Julia Extrema Range** with `Sensitivity: 25%–35%`.
