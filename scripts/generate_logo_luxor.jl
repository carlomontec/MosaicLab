#!/usr/bin/env julia
# ==============================================================================
# MosaicLab — Vector Icon Generator via Luxor.jl
# ==============================================================================
# Demonstrates geometric mosaic tile matrix drawing in Julia using Luxor.
# Requirements:
#   julia -e 'using Pkg; Pkg.add("Luxor")'
# Usage:
#   julia generate_logo_luxor.jl
# ==============================================================================

using Luxor

function draw_tile(x, y, size, r, fill_col; has_bevel=true, has_glint=false)
    setcolor(fill_col)
    roundrect(Point(x, y), size, size, r, :fill)
    
    if has_bevel
        setcolor(1.0, 1.0, 1.0, 0.25)
        setline(1.0)
        roundrect(Point(x, y), size, size, r, :stroke)
    end
    
    if has_glint
        setcolor(1.0, 1.0, 1.0, 0.30)
        roundrect(Point(x + 2, y + 2), size - 4, size / 3, 2, :fill)
    end
end

function generate_icon(output_path="AppIcon_from_luxor.png"; canvas_size=1024)
    Drawing(canvas_size, canvas_size, output_path)
    origin() # (0, 0) at center

    # 1. Background macOS Squircle (824x824 at 1024 master)
    squircle_size = 824
    corner_radius = 185
    
    # Base dark gradient
    setcolor(0.06, 0.07, 0.09)
    roundrect(Point(-squircle_size/2, -squircle_size/2), squircle_size, squircle_size, corner_radius, :fill)
    
    # Subtle rim highlight
    setcolor(1.0, 1.0, 1.0, 0.20)
    setline(2.5)
    roundrect(Point(-squircle_size/2, -squircle_size/2), squircle_size, squircle_size, corner_radius, :stroke)

    # 2. Ambient glows
    # Blue glow behind M
    # Purple glow behind L

    # 3. 18x18 Mosaic Matrix
    pitch = 36
    tile_size = 31
    corner_r = 4.5
    total_w = 18 * pitch - (pitch - tile_size)
    start_x = -total_w / 2
    start_y = -total_w / 2

    m_pattern = [
        "##.....##",
        "###...###",
        "##.#.#.##",
        "##..#..##",
        "##.....##",
        "##.....##",
        "##.....##",
        "##.....##",
        "##.....##",
        "##.....##"
    ]

    l_pattern = [
        "##...",
        "##...",
        "##...",
        "##...",
        "##...",
        "##...",
        "##...",
        "##...",
        "#####",
        "#####"
    ]

    # Grid mapping
    grid = fill('.', 18, 18)
    for (r, row) in enumerate(m_pattern)
        for (c, ch) in enumerate(row)
            if ch == '#'
                grid[4 + r, 1 + c] = 'M'
            end
        end
    end

    for (r, row) in enumerate(l_pattern)
        for (c, ch) in enumerate(row)
            if ch == '#'
                grid[4 + r, 12 + c] = 'L'
            end
        end
    end

    # Render tiles
    for r in 1:18
        for c in 1:18
            cell = grid[r, c]
            x = start_x + (c - 1) * pitch
            y = start_y + (r - 1) * pitch

            if cell == '.'
                draw_tile(x, y, tile_size, corner_r, (0.07, 0.08, 0.11); has_bevel=false)
            elseif cell == 'M'
                rel_r = r - 5
                rel_c = c - 2
                col = if rel_r == 0 && rel_c in [0, 1, 7, 8]
                    (0.22, 0.74, 0.97) # Cyan highlight
                elseif rel_r >= 8
                    (0.11, 0.31, 0.85) # Deep cobalt
                else
                    (0.15, 0.39, 0.92) # Royal blue
                end
                draw_tile(x, y, tile_size, corner_r, col; has_bevel=true, has_glint=(rel_r <= 1))
            elseif cell == 'L'
                rel_r = r - 5
                rel_c = c - 13
                col = if rel_r == 0 && rel_c in [0, 1]
                    (0.91, 0.47, 0.98) # Orchid highlight
                elseif rel_r >= 8
                    (0.42, 0.13, 0.66) # Deep violet
                else
                    (0.58, 0.20, 0.92) # Amethyst
                end
                draw_tile(x, y, tile_size, corner_r, col; has_bevel=true, has_glint=(rel_r <= 1))
            end
        end
    end

    finish()
    println("Generated Luxor icon: ", output_path)
end

if abspath(PROGRAM_FILE) == @__FILE__
    generate_icon("MosaicLab/docs/AppIcon_luxor.png")
end
