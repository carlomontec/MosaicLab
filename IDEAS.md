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

## 🔬 Exploration & Research Ideas

### 3. Apple Vision Saliency-Guided Voronoi Tessellation 🏛️
- Use Apple's Vision framework (`VNGenerateAttentionBasedSaliencyImageRequest`) to compute subject saliency maps.
- Seed Voronoi relaxation points densely over high-saliency features (faces, focal objects) and sparsely over backgrounds.
- Generates organic, stained-glass / Roman mosaic aesthetics with smooth Lloyd's relaxation.

### 4. Global Optimal Assignment for "No Duplicates" (Auction / Hungarian Algorithm) 🧩
- Currently, when `--max-reuse 1` is enabled, candidates are placed greedily based on the order photos are scanned.
- A global Linear Sum Assignment (or Bertsekas Auction algorithm) would find the mathematically optimal $1$-to-$1$ bijection between all $N$ tiles and $N$ constituent photos, maximizing total mosaic fidelity across the whole image simultaneously.

### 5. Tile Drag-to-Swap & Direct Reassignment 🖐️
- Allow the user to drag a photo from one tile directly onto another tile on the canvas to swap them.
- Provide an "Undo / Redo" stack for manual tile modifications.

### 6. Apple Neural Engine Semantic Matching (FeaturePrint Embeddings) 🧠
- Utilize Vision framework `VNGenerateImageFeaturePrintRequest` to compute high-level semantic vector embeddings.
- Combine color/spectral distance with semantic concept matching:
  $$\text{Score} = \alpha \cdot D_{\text{color}} + (1 - \alpha) \cdot D_{\text{semantic}}$$
- Allows placing photos of eyes in eye tiles, flower photos in floral regions, or sky photos in celestial regions.

---

## 📝 Change Log & Ideas Tracker
- **2026-09-24**: Added Optimization Convergence History and GUI-to-CLI Recipe Exporter (suggested by Carlo Monjaraz-Tec).
