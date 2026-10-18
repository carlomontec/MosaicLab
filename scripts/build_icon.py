#!/usr/bin/env python3
"""
MosaicLab App Icon Generator
============================
Generates the official macOS vector SVG, high-resolution PNG, and multi-scale ICNS bundle.
Aesthetic:
- Pixel art / mosaic tile matrix 'ML' monogram (MosaicLab)
- 'M' in vibrant cyan/azure/cobalt with specular glints
- 'L' in vibrant orchid/lavender/amethyst with specular glints
- Tactile 18x18 mosaic grid with dark slate negative-space matrix cells
- macOS HIG compliant continuous squircle frame (824x824 at 1024x1024 canvas) with elevation lighting
"""

import os
import shutil
import subprocess
import sys

def build_svg(filepath):
    m_pattern = [
        '##.....##',  # r=0
        '###...###',  # r=1
        '##.#.#.##',  # r=2
        '##..#..##',  # r=3
        '##.....##',  # r=4
        '##.....##',  # r=5
        '##.....##',  # r=6
        '##.....##',  # r=7
        '##.....##',  # r=8
        '##.....##',  # r=9
    ]
    
    l_pattern = [
        '##...',  # r=0
        '##...',  # r=1
        '##...',  # r=2
        '##...',  # r=3
        '##...',  # r=4
        '##...',  # r=5
        '##...',  # r=6
        '##...',  # r=7
        '#####',  # r=8
        '#####',  # r=9
    ]
    
    grid = [['.' for _ in range(18)] for _ in range(18)]
    
    # Populate M (cols 1..9, rows 4..13)
    for r_idx, row_str in enumerate(m_pattern):
        for c_idx, ch in enumerate(row_str):
            if ch == '#':
                grid[4 + r_idx][1 + c_idx] = 'M'
                
    # Populate L (cols 12..16, rows 4..13)
    for r_idx, row_str in enumerate(l_pattern):
        for c_idx, ch in enumerate(row_str):
            if ch == '#':
                grid[4 + r_idx][12 + c_idx] = 'L'

    pitch = 36
    tile_size = 31
    corner_r = 4.5
    
    total_grid_w = 18 * pitch - (pitch - tile_size)
    start_x = (1024 - total_grid_w) // 2
    start_y = (1024 - total_grid_w) // 2
    
    tile_elements = []
    
    for r in range(18):
        for c in range(18):
            cell = grid[r][c]
            x = start_x + c * pitch
            y = start_y + r * pitch
            
            if cell == '.':
                tile_elements.append(
                    f'<rect x="{x}" y="{y}" width="{tile_size}" height="{tile_size}" rx="{corner_r}" '
                    f'fill="#13151c" stroke="#ffffff" stroke-opacity="0.04" stroke-width="1"/>'
                )
            elif cell == 'M':
                rel_r = r - 4
                rel_c = c - 1
                
                if rel_r == 0 and rel_c in [0, 1, 7, 8]:
                    fill = "#38bdf8"
                elif rel_r == 1 and rel_c in [0, 1, 2, 6, 7, 8]:
                    fill = "#0ea5e9"
                elif rel_r in [2, 3] and rel_c in [2, 3, 4, 5, 6]:
                    fill = "#0284c7"
                elif rel_r >= 8:
                    fill = "#1d4ed8"
                elif rel_c in [0, 7]:
                    fill = "#0284c7"
                else:
                    fill = "#2563eb"
                    
                g = f'<g>'
                g += f'<rect x="{x}" y="{y}" width="{tile_size}" height="{tile_size}" rx="{corner_r}" fill="{fill}"/>'
                g += f'<rect x="{x}" y="{y}" width="{tile_size}" height="{tile_size}" rx="{corner_r}" fill="none" stroke="#ffffff" stroke-opacity="0.25" stroke-width="1"/>'
                if rel_r <= 1:
                    g += f'<rect x="{x+2}" y="{y+2}" width="{tile_size-4}" height="{tile_size//3}" rx="2" fill="#ffffff" fill-opacity="0.30"/>'
                g += '</g>'
                tile_elements.append(g)
                
            elif cell == 'L':
                rel_r = r - 4
                rel_c = c - 12
                
                if rel_r == 0 and rel_c in [0, 1]:
                    fill = "#e879f9"
                elif rel_r == 1 and rel_c in [0, 1]:
                    fill = "#d946ef"
                elif rel_r in [2, 3, 4] and rel_c in [0, 1]:
                    fill = "#c084fc"
                elif rel_r >= 8:
                    fill = "#6b21a8"
                elif rel_c == 0:
                    fill = "#a855f7"
                else:
                    fill = "#9333ea"
                    
                g = f'<g>'
                g += f'<rect x="{x}" y="{y}" width="{tile_size}" height="{tile_size}" rx="{corner_r}" fill="{fill}"/>'
                g += f'<rect x="{x}" y="{y}" width="{tile_size}" height="{tile_size}" rx="{corner_r}" fill="none" stroke="#ffffff" stroke-opacity="0.25" stroke-width="1"/>'
                if rel_r <= 1:
                    g += f'<rect x="{x+2}" y="{y+2}" width="{tile_size-4}" height="{tile_size//3}" rx="2" fill="#ffffff" fill-opacity="0.30"/>'
                g += '</g>'
                tile_elements.append(g)

    tiles_markup = "\n    ".join(tile_elements)

    svg_content = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
  <defs>
    <filter id="mac-shadow" x="-20%" y="-20%" width="140%" height="150%">
      <feDropShadow dx="0" dy="28" stdDeviation="24" flood-color="#000000" flood-opacity="0.45"/>
      <feDropShadow dx="0" dy="8" stdDeviation="10" flood-color="#000000" flood-opacity="0.30"/>
    </filter>

    <radialGradient id="base-bg" cx="50%" cy="26%" r="80%">
      <stop offset="0%" stop-color="#1d2028"/>
      <stop offset="60%" stop-color="#101115"/>
      <stop offset="100%" stop-color="#08090c"/>
    </radialGradient>

    <linearGradient id="rim-stroke" x1="0%" y1="0%" x2="0%" y2="100%">
      <stop offset="0%" stop-color="#ffffff" stop-opacity="0.24"/>
      <stop offset="40%" stop-color="#ffffff" stop-opacity="0.08"/>
      <stop offset="100%" stop-color="#000000" stop-opacity="0.4"/>
    </linearGradient>

    <radialGradient id="m-glow" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="#0284c7" stop-opacity="0.30"/>
      <stop offset="100%" stop-color="#0284c7" stop-opacity="0.0"/>
    </radialGradient>
    <radialGradient id="l-glow" cx="50%" cy="50%" r="50%">
      <stop offset="0%" stop-color="#a855f7" stop-opacity="0.30"/>
      <stop offset="100%" stop-color="#a855f7" stop-opacity="0.0"/>
    </radialGradient>

    <filter id="tiles-elevation" x="-10%" y="-10%" width="120%" height="120%">
      <feDropShadow dx="0" dy="4" stdDeviation="5" flood-color="#000000" flood-opacity="0.35"/>
    </filter>
  </defs>

  <g filter="url(#mac-shadow)">
    <rect x="100" y="100" width="824" height="824" rx="185" ry="185" fill="url(#base-bg)"/>
    <rect x="100" y="100" width="824" height="824" rx="185" ry="185" fill="none" stroke="url(#rim-stroke)" stroke-width="2.5"/>
  </g>

  <circle cx="380" cy="512" r="260" fill="url(#m-glow)"/>
  <circle cx="640" cy="512" r="260" fill="url(#l-glow)"/>

  <g id="mosaic-grid" filter="url(#tiles-elevation)">
    {tiles_markup}
  </g>

  <path d="M 100 100 L 600 100 L 100 600 Z" fill="#ffffff" opacity="0.03" pointer-events="none"/>
</svg>
'''
    with open(filepath, 'w') as f:
        f.write(svg_content)

def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    docs_dir = os.path.join(root, "docs")
    os.makedirs(docs_dir, exist_ok=True)
    
    svg_path = os.path.join(docs_dir, "AppIcon.svg")
    png_path = os.path.join(docs_dir, "AppIcon.png")
    icns_path = os.path.join(docs_dir, "AppIcon.icns")
    iconset_dir = os.path.join(docs_dir, "AppIcon.iconset")
    
    print("==> 1. Generating vector SVG...")
    build_svg(svg_path)
    
    print("==> 2. Rendering master 1024x1024 PNG...")
    subprocess.run(["rsvg-convert", "-w", "1024", "-h", "1024", svg_path, "-o", png_path], check=True)
    
    print("==> 3. Generating macOS iconset...")
    os.makedirs(iconset_dir, exist_ok=True)
    sizes = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024),
    ]
    for filename, size in sizes:
        dest = os.path.join(iconset_dir, filename)
        subprocess.run(["rsvg-convert", "-w", str(size), "-h", str(size), svg_path, "-o", dest], check=True)
        
    print("==> 4. Compiling ICNS with iconutil...")
    subprocess.run(["iconutil", "-c", "icns", iconset_dir, "-o", icns_path], check=True)
    shutil.rmtree(iconset_dir)
    
    # Copy to app bundle if present
    app_res_dir = os.path.join(root, "MosaicLab.app", "Contents", "Resources")
    if os.path.isdir(os.path.dirname(app_res_dir)):
        os.makedirs(app_res_dir, exist_ok=True)
        shutil.copy2(icns_path, os.path.join(app_res_dir, "AppIcon.icns"))
        print(f"==> Copied icon to {app_res_dir}/AppIcon.icns")
        
    print(f"==> Successfully generated all icon assets:")
    print(f"    - SVG:  {svg_path}")
    print(f"    - PNG:  {png_path}")
    print(f"    - ICNS: {icns_path}")

if __name__ == "__main__":
    main()
