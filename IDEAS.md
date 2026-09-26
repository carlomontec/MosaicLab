# MosaicLab — Future Ideas & Improvement Roadmap 💡

This document captures architectural concepts, user feedback, and high-impact feature ideas for upcoming versions of **MosaicLab**.

---

## 🎯 High-Priority Concepts

### 1. Optimization Convergence History & Real-Time Plotting 📈
*Suggested by Carlo Monjaraz-Tec*

**Concept:**
As the solver iterates through thousands of source photos, track the global mosaic match quality over time and visualize the convergence trajectory in a live chart.

**Key Mechanics & Design:**
- **Metric Formulation**:
  - Sample global average match score:
    $$\bar{S}(t) = \frac{1}{N_{\text{matched}}} \sum_{i=1}^{N_{\text{matched}}} S_i(t)$$
  - Convert to an intuitive **Global Match Quality %**:
    $$Q(t) = \max\left(0, \min\left(100, 100 \times (1.0 - \bar{S}(t))\right)\right)$$
- **Live GUI Visualization**:
  - A collapsible or popover analytics panel containing a real-time sparkline graph (using Swift Charts or lightweight vector bezier path).
  - Shows the steep initial ascent as empty tiles are filled with coarse matches, followed by the asymptotic refinement curve as superior candidates displace earlier ones.
- **Analytics & Plateau Detection**:
  - Display metrics:
    - *Initial Match Quality* $\to$ *Current Match Quality*.
    - *Total Tile Replacements* (how many times tiles swapped for better photos).
    - *Diminishing Returns Indicator*: Alerts the user when further library scanning yields negligible improvements (<0.01% gain over the last 1,000 photos).
  - Optional export of the trajectory data (`time, photos_processed, quality_pct, replacements`) to `.csv` or `.json` for benchmarking and research.

---

### 2. GUI-to-CLI Recipe Exporter ("Copy as CLI Command") 📋⚡
*Suggested by Carlo Monjaraz-Tec*

**Concept:**
Once a user fine-tunes their ideal mosaic in the GUI (shape, tessellation algorithm, sensitivity, color transfer, edge alignment, cutlines, reuse constraints), provide a one-click button to export the exact corresponding `macosaix-cli` command.

**Key Mechanics & Design:**
- **UI Access Points**:
  - Toolbar or File Menu item: **"Copy as CLI Command"** (`⌘⌥C`).
  - Button inside the Export Sheet: **"Generate Shell Script..."**.
- **Generated Command Format**:
  Automatically serializes the entire GUI state into a clean, shell-escaped string:
  ```bash
  macosaix-cli \
    --target "~/Pictures/Portrait.heic" \
    --sources "~/Pictures/Photos" \
    --shape quadtree \
    --quadtree-algo whole \
    --quadtree-depth 4 \
    --quadtree-thresh 0.15 \
    --quadtree-min-tile 8 \
    --color-transfer 0.35 \
    --edge-weight 0.25 \
    --metric riemersma \
    --stroke 0.5 \
    --stroke-color black \
    --width 3000 \
    --output "~/Desktop/mosaic_output.png"
  ```
- **Why This Is Powerful**:
  - **Batch Reproducibility**: Users can take their perfected recipe, drop it into a shell script or loop, and generate dozens of mosaics for different family members or events just by changing `--target`.
  - **Headless Servers & Automation**: Setup on a MacBook GUI, then run overnight or on remote servers via SSH using the CLI.

---

### 3. Match Quality Heatmap with Perceptual Colormaps (Cubehelix) 🗺️🎨
*Suggested by Carlo Monjaraz-Tec*

**Concept:**
Provide an overlay and diagnostic inspection mode that visualizes tile-by-tile match quality across the entire canvas as a continuous heatmap. Tiles with exceptional matches appear bright or cool, while poor matches or color voids stand out in contrasting tones. This provides instant visual feedback indicating where the user's photo collection lacks sufficient chromatic or luminance diversity (e.g. "need more warm golden-hour tones, deep blues, or dark foliage").

**Key Mechanics & Design:**
- **Perceptual Colormap (Cubehelix)**:
  - Implement Dave Green's Cubehelix color mapping algorithm:
    $$C(x) = x^\gamma + a \cdot x^\gamma (1 - x^\gamma) \begin{pmatrix} -0.14861 & 1.78277 \\ -0.29227 & -0.90649 \\ 1.97294 & 0 \end{pmatrix} \begin{pmatrix} \cos \phi \\ \sin \phi \end{pmatrix}$$
    where $\phi = 2\pi (s/3 + r \cdot x)$.
  - **Monotonic Luminance Advantage**: Unlike rainbow or jet colormaps, Cubehelix increases monotonically in perceived luminance from dark to bright, meaning it preserves diagnostic contrast even when converted to grayscale or viewed by color-deficient users.
  - Configurable parameters: start color ($s$), rotations ($r$), saturation ($a$), and gamma ($\gamma$).
  - Option to toggle between **Cubehelix** (default), **Viridis**, or **Magma**.
- **Diagnostics & User Guidance**:
  - Highlights tile clusters with high matching error ($S_i > \text{threshold}$) or unfilled blank tiles.
  - Generates actionable library advice: e.g. *"Tiles in region [X, Y] have low match quality (predominantly deep amber/orange). Consider adding photos with warm sunset or indoor lighting to improve fidelity."*
- **UI Integration**:
  - A toggle button in the floating canvas controls bar: **"Match Quality Heatmap"** (keyboard shortcut `⌥H` or segmented control next to the Blend slider).
  - Hovering or clicking on a tile in Heatmap mode displays its exact numerical error score and delta breakdown (Luminance, Chroma, Edge alignment).

---

### 4. Global Image Ban & Diverse Multi-Substitute Replacement 🚫🔄
*Suggested by Carlo Monjaraz-Tec*

**Concept:**
When inspecting a generated mosaic, a user may identify a specific photograph they dislike, find unflattering, or notice being visually repetitive. Clicking on any tile displaying that photo allows them to select **"Ban & Replace All Occurrences"**. The engine strips every instance of this picture across the entire mosaic and dynamically substitutes each affected tile with fresh, diverse alternatives.

**Key Mechanics & Design:**
- **Persistent Exclusion Blacklist**:
  - The banned photo identifier (URL or Photos asset ID) is added to `bannedImageIdentifiers: Set<String>`.
  - The engine permanently excludes this image from all future substitution passes and incremental library scans for this project.
- **Diverse Multi-Candidate Re-solving (Anti-Monopoly)**:
  - **The Problem**: If an image was used in 10 tiles, naively picking the global second-best image would simply replace one repetitive photo with another duplicate.
  - **Dispersion & Diversity Algorithm**:
    - The batch substitution pass re-solves each affected tile while enforcing strict local variety: replacements must be spread across multiple distinct candidates (e.g. at least 3–4 different photos for $K \ge 4$ occurrences).
    - Caps any substitute's reuse factor ($R_{\text{sub}} \le \lceil K / 3 \rceil$) and enforces spatial dispersion (`minDistance`) so replacements do not clump together.
- **UI Integration**:
  - Inside `TileDetailPopover`:
    - Shows how many other tiles currently use this photo: *"Used in 7 tiles"*.
    - Button: **"Ban & Replace All (7 tiles)..."** with a confirmation dialog and full Undo support.
  - Interactive canvas feedback: briefly highlights or pulses the affected tiles as they transition to their new diverse photos.

---

## 🔬 Exploration & Research Ideas

### 5. Apple Vision Saliency-Guided Voronoi Tessellation 🏛️
- Use Apple's Vision framework (`VNGenerateAttentionBasedSaliencyImageRequest`) to compute subject saliency maps.
- Seed Voronoi relaxation points densely over high-saliency features (faces, focal objects) and sparsely over backgrounds.
- Generates organic, stained-glass / Roman mosaic aesthetics with smooth Lloyd's relaxation.

### 6. Global Optimal Assignment for "No Duplicates" (Auction / Hungarian Algorithm) 🧩
- Currently, when `--max-reuse 1` is enabled, candidates are placed greedily based on the order photos are scanned.
- A global Linear Sum Assignment (or Bertsekas Auction algorithm) would find the mathematically optimal $1$-to-$1$ bijection between all $N$ tiles and $N$ constituent photos, maximizing total mosaic fidelity across the whole image simultaneously.

### 7. Tile Drag-to-Swap & Direct Reassignment 🖐️
- Allow the user to drag a photo from one tile directly onto another tile on the canvas to swap them.
- Provide an "Undo / Redo" stack for manual tile modifications.

### 8. Apple Neural Engine Semantic Matching (FeaturePrint Embeddings) 🧠
- Utilize Vision framework `VNGenerateImageFeaturePrintRequest` to compute high-level semantic vector embeddings.
- Combine color/spectral distance with semantic concept matching:
  $$\text{Score} = \alpha \cdot D_{\text{color}} + (1 - \alpha) \cdot D_{\text{semantic}}$$
- Allows placing photos of eyes in eye tiles, flower photos in floral regions, or sky photos in celestial regions.

---

## 📝 Change Log & Ideas Tracker
- **2026-09-26**: Added Global Image Ban & Diverse Multi-Substitute Replacement (suggested by Carlo Monjaraz-Tec).
- **2026-09-26**: Added Match Quality Heatmap with Perceptual Colormaps / Cubehelix (suggested by Carlo Monjaraz-Tec).
- **2026-09-24**: Added Optimization Convergence History and GUI-to-CLI Recipe Exporter (suggested by Carlo Monjaraz-Tec).
