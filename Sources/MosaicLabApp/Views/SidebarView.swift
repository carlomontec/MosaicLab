import SwiftUI
import AppKit
import MosaicLabKit

public struct SidebarView: View {
    @EnvironmentObject private var viewModel: MosaicViewModel
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Section 1: Target Image
                GroupBox(label: Label("Original Image", systemImage: "photo")) {
                    VStack(alignment: .leading, spacing: 8) {
                        TargetImageWell()
                    }
                    .padding(.top, 4)
                }
                
                // Section 2: Tile Shapes
                GroupBox(label: Label("Tile Shapes", systemImage: "square.grid.2x2")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Shape", selection: $viewModel.shapeType) {
                            Text("Square").tag(MosaicShapeType.rectangular)
                            Text("Hexagon").tag(MosaicShapeType.hexagonal)
                            Text("Puzzle").tag(MosaicShapeType.puzzle)
                            Text("Adaptive").tag(MosaicShapeType.quadtree)
                        }
                        .pickerStyle(.segmented)
                        .disabled(viewModel.isRunning)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(viewModel.shapeType == .quadtree ? "Base Grid Across:" : "Tiles Across:")
                                Spacer()
                                Text("\(viewModel.tilesAcross)")
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                            }
                            .font(.caption)
                            Slider(value: Binding(
                                get: { Double(viewModel.tilesAcross) },
                                set: { viewModel.tilesAcross = Int($0) }
                            ), in: (viewModel.shapeType == .quadtree ? 4...30 : 10...80), step: 2)
                            .disabled(viewModel.isRunning)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(viewModel.shapeType == .quadtree ? "Base Grid Down:" : "Tiles Down:")
                                Spacer()
                                Text("\(viewModel.tilesDown)")
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                            }
                            .font(.caption)
                            Slider(value: Binding(
                                get: { Double(viewModel.tilesDown) },
                                set: { viewModel.tilesDown = Int($0) }
                            ), in: (viewModel.shapeType == .quadtree ? 4...24 : 10...60), step: 2)
                            .disabled(viewModel.isRunning)
                        }
                        
                        if viewModel.shapeType == .quadtree {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Segmentation Algorithm:")
                                    .font(.caption)
                                Picker("", selection: $viewModel.quadtreeAlgorithm) {
                                    Text("Julia Range (max - min)").tag("juliaRange")
                                    Text("Whole Canvas Quadtree").tag("wholeCanvas")
                                    Text("RGB Color Range").tag("colorRange")
                                    Text("Variance / Hybrid (Legacy)").tag("variance")
                                }
                                .pickerStyle(.menu)
                                .disabled(viewModel.isRunning)
                                .help("Julia Range: strict (max - min) contrast, ideal for fine details like eyes and lips. Whole Canvas: starts with 1 root tile covering the full image. RGB Color: includes chromatic edges. Variance: classic standard deviation.")
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Min Tile Size Floor:")
                                    Spacer()
                                    Text("\(Int(viewModel.quadtreeMinTileDim)) px")
                                        .foregroundColor(.secondary)
                                        .monospacedDigit()
                                }
                                .font(.caption)
                                Picker("", selection: $viewModel.quadtreeMinTileDim) {
                                    Text("4 px").tag(4.0)
                                    Text("8 px").tag(8.0)
                                    Text("16 px").tag(16.0)
                                    Text("24 px").tag(24.0)
                                    Text("32 px").tag(32.0)
                                    Text("48 px").tag(48.0)
                                }
                                .pickerStyle(.segmented)
                                .disabled(viewModel.isRunning)
                                .help("Hardware safety floor in screen pixels. Quadtree subdivision stops if a tile would become smaller than this floor.")
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Max Subdivision:")
                                    Spacer()
                                    let levelDesc = viewModel.quadtreeMaxDepth == 1 ? "Halves (2×)" :
                                                   viewModel.quadtreeMaxDepth == 2 ? "Quarters (4×)" :
                                                   viewModel.quadtreeMaxDepth == 3 ? "Eighths (8×)" :
                                                   viewModel.quadtreeMaxDepth == 4 ? "Sixteenths (16×)" : "Thirty-seconds (32×)"
                                    Text("Level \(viewModel.quadtreeMaxDepth) · \(levelDesc)")
                                        .foregroundColor(.secondary)
                                        .monospacedDigit()
                                }
                                .font(.caption)
                                Slider(value: Binding(
                                    get: { Double(viewModel.quadtreeMaxDepth) },
                                    set: { viewModel.quadtreeMaxDepth = Int($0) }
                                ), in: 1...5, step: 1)
                                .disabled(viewModel.isRunning)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Detail Sensitivity:")
                                    Button(action: {
                                        viewModel.showingQuadtreeInfo.toggle()
                                    }) {
                                        Image(systemName: "info.circle")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Learn about Adaptive Multi-Resolution Quadtree Tiling & Academic Citations")
                                    .popover(isPresented: $viewModel.showingQuadtreeInfo, arrowEdge: .trailing) {
                                        QuadtreeInfoView {
                                            viewModel.showingQuadtreeInfo = false
                                        }
                                    }
                                    
                                    Spacer()
                                    let sensPct = Int(round(max(0.0, min(1.0, (0.85 - viewModel.quadtreeThreshold) / 0.80)) * 100))
                                    Text("\(sensPct)%")
                                        .foregroundColor(.secondary)
                                        .monospacedDigit()
                                }
                                .font(.caption)
                                Slider(value: Binding(
                                    get: {
                                        let s = (0.85 - viewModel.quadtreeThreshold) / 0.80
                                        return max(0.0, min(1.0, s))
                                    },
                                    set: { newSens in
                                        let thresh = 0.85 - (newSens * 0.80)
                                        viewModel.quadtreeThreshold = round(thresh * 1000.0) / 1000.0
                                    }
                                ), in: 0.0...1.0, step: 0.01)
                                .disabled(viewModel.isRunning)
                            }
                            
                            Toggle("2:1 Balanced Transitions", isOn: $viewModel.quadtreeBalanced)
                                .font(.caption)
                                .disabled(viewModel.isRunning)
                                .help("Ensures adjacent tiles differ by at most one subdivision level for smooth, organic transitions (Klein et al. 2002)")
                            
                            if viewModel.quadtreeAlgorithm == "variance" {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Detail Mode:")
                                        .font(.caption)
                                    Picker("", selection: Binding(
                                        get: {
                                            if viewModel.quadtreeDetailAlpha <= 0.3 { return "edge" }
                                            else if viewModel.quadtreeDetailAlpha >= 0.7 { return "texture" }
                                            else { return "balanced" }
                                        },
                                        set: { mode in
                                            switch mode {
                                            case "edge": viewModel.quadtreeDetailAlpha = 0.2
                                            case "texture": viewModel.quadtreeDetailAlpha = 0.8
                                            default: viewModel.quadtreeDetailAlpha = 0.5
                                            }
                                        }
                                    )) {
                                        Text("Edge-Aware").tag("edge")
                                        Text("Balanced").tag("balanced")
                                        Text("Texture").tag("texture")
                                    }
                                    .pickerStyle(.segmented)
                                    .disabled(viewModel.isRunning)
                                    .help("Edge-Aware: subdivides at structural boundaries. Balanced: blend of edges + texture. Texture: subdivides noisy/textured areas.")
                                }
                            }
                        }
                        
                        if viewModel.shapeType == .puzzle {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Puzzle Curviness:")
                                    Spacer()
                                    Text(String(format: "%.1f", viewModel.curviness))
                                        .foregroundColor(.secondary)
                                        .monospacedDigit()
                                }
                                .font(.caption)
                                Slider(value: $viewModel.curviness, in: 0.0...1.0, step: 0.1)
                                .disabled(viewModel.isRunning)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Piece Cutlines:")
                                Spacer()
                                Text(viewModel.strokeWidth > 0 ? String(format: "%.1f px", viewModel.strokeWidth) : "Off")
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                            }
                            .font(.caption)
                            Slider(value: $viewModel.strokeWidth, in: 0.0...2.0, step: 0.25)
                            
                            if viewModel.strokeWidth > 0 {
                                HStack {
                                    Text("Cutline Color:")
                                        .font(.caption)
                                    Spacer()
                                    Picker("", selection: $viewModel.strokeColor) {
                                        Text("Dark").tag("black")
                                        Text("White").tag("white")
                                    }
                                    .pickerStyle(.segmented)
                                    .frame(width: 120)
                                }
                                .padding(.top, 2)
                            }
                        }
                        
                        HStack {
                            Text("Total Tiles:")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(viewModel.totalTilesCount)")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        }
                        
                        if viewModel.shapeType == .quadtree && !viewModel.quadtreeSizeSummary.isEmpty {
                            Text(viewModel.quadtreeSizeSummary)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                    }
                    .padding(.top, 4)
                }
                
                // Section 3: Photo Sources
                GroupBox(label: Label("Photo Sources", systemImage: "photo.stack")) {
                    VStack(alignment: .leading, spacing: 10) {
                        // Source 1: Apple Photos
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Toggle(isOn: $viewModel.useApplePhotos) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "photo.stack")
                                            .foregroundColor(.accentColor)
                                        Text("Apple Photos")
                                            .fontWeight(.medium)
                                    }
                                }
                                .toggleStyle(.checkbox)
                                .disabled(viewModel.isRunning)
                                
                                Spacer()
                                
                                if viewModel.useApplePhotos && viewModel.isPhotosAuthorized {
                                    Button(action: {
                                        viewModel.refreshPhotosAuthorization()
                                    }) {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(viewModel.isRunning || viewModel.isLoadingPhotos)
                                    .help("Refresh Photos library")
                                }
                            }
                            
                            if viewModel.useApplePhotos {
                                if !viewModel.isPhotosAuthorized {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Photos access is required to use images from your Photos library.")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Button("Connect Photos Library") {
                                            viewModel.requestPhotosAccess()
                                        }
                                        .controlSize(.small)
                                        .buttonStyle(.borderedProminent)
                                    }
                                    .padding(8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(Color.accentColor.opacity(0.08))
                                    )
                                } else {
                                    HStack {
                                        Text("Album:")
                                            .font(.caption)
                                        Spacer()
                                        Picker("", selection: $viewModel.selectedAlbumID) {
                                            ForEach(viewModel.availableAlbums) { album in
                                                Label("\(album.title) (\(album.count))", systemImage: album.iconName)
                                                    .tag(album.id)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .disabled(viewModel.isRunning || viewModel.isLoadingPhotos)
                                    }
                                    
                                    HStack {
                                        if viewModel.isLoadingPhotos {
                                            ProgressView().controlSize(.mini)
                                            Text("Loading album...")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        } else {
                                            Text("\(viewModel.applePhotosCandidateItems.count) photos in album")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                    }
                                }
                            }
                        }
                        
                        Divider()
                        
                        // Source 2: Local Folders
                        VStack(alignment: .leading, spacing: 6) {
                            Toggle(isOn: $viewModel.useLocalFolders) {
                                HStack(spacing: 4) {
                                    Image(systemName: "folder")
                                        .foregroundColor(.accentColor)
                                    Text("Local Folders")
                                        .fontWeight(.medium)
                                }
                            }
                            .toggleStyle(.checkbox)
                            .disabled(viewModel.isRunning)
                            
                            if viewModel.useLocalFolders {
                            if viewModel.sourceFolders.isEmpty {
                                Text("No folders added yet.\nDrag & drop folders here or click + Add Folder.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 4)
                            } else {
                                ForEach(viewModel.sourceFolders, id: \.self) { folder in
                                    HStack {
                                        Image(systemName: "folder.fill")
                                            .foregroundColor(.accentColor)
                                            .font(.caption)
                                        Text(folder.lastPathComponent)
                                            .font(.caption)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                        Spacer()
                                        Button(action: {
                                            viewModel.removeSourceFolder(folder)
                                        }) {
                                            Image(systemName: "trash")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                            
                            HStack {
                                Button("+ Add Folder...") {
                                    chooseSourceFolder()
                                }
                                .controlSize(.small)
                                .disabled(viewModel.isRunning)
                                
                                Spacer()
                                
                                if !viewModel.localCandidateItems.isEmpty {
                                    Text("\(viewModel.localCandidateItems.count) photos")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                        
                        Divider()
                        
                        // Pool Summary & Breakdown
                        HStack {
                            Text("Total Pool:")
                                .font(.caption)
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(viewModel.candidateItems.count) photos")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        }
                        
                        if !viewModel.formatBreakdownText.isEmpty {
                            Text(viewModel.formatBreakdownText)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        if !viewModel.candidateItems.isEmpty && viewModel.totalTilesCount > 0 && viewModel.candidateItems.count < viewModel.totalTilesCount {
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text("Tip: You have fewer photos (\(viewModel.candidateItems.count)) than tiles (\(viewModel.totalTilesCount)). For best results, set Max Reuse to Unlimited and Blend to 15–25%.")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.orange.opacity(0.1))
                            )
                        }
                    }
                    .padding(.top, 4)
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(viewModel.isSourcesDropTargeted ? Color.accentColor : Color.clear, lineWidth: 2)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(viewModel.isSourcesDropTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
                        )
                )
                .onDrop(of: [.fileURL], isTargeted: $viewModel.isSourcesDropTargeted) { providers in
                    viewModel.useLocalFolders = true
                    handleDroppedSources(providers)
                    return true
                }
                
                // Section 4: Image Usage Constraints
                GroupBox(label: Label("Placement Rules", systemImage: "slider.horizontal.3")) {
                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Max Reuse:")
                                Spacer()
                                Text(viewModel.maxReuse == 0 ? "Unlimited" : "\(viewModel.maxReuse)×")
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                            }
                            .font(.caption)
                            Slider(value: Binding(
                                get: { Double(viewModel.maxReuse) },
                                set: { viewModel.maxReuse = Int($0) }
                            ), in: 0...10, step: 1)
                            .disabled(viewModel.isRunning)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Min Distance:")
                                Spacer()
                                Text("\(viewModel.minDistance) tiles")
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                            }
                            .font(.caption)
                            Slider(value: Binding(
                                get: { Double(viewModel.minDistance) },
                                set: { viewModel.minDistance = Int($0) }
                            ), in: 0...6, step: 1)
                            .disabled(viewModel.isRunning)
                        }
                        
                        Picker("Metric", selection: $viewModel.colorMetric) {
                            Text("Riemersma (Eye)").tag(MosaicColorMetric.riemersma)
                            Text("RGB Distance").tag(MosaicColorMetric.RGB)
                            Text("Monochrome (B&W)").tag(MosaicColorMetric.monochrome)
                        }
                        .pickerStyle(.menu)
                        .font(.caption)
                        .disabled(viewModel.isRunning)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Text("Edge Alignment:")
                                Button(action: {
                                    viewModel.showingEdgeMatchingInfo.toggle()
                                }) {
                                    Image(systemName: "info.circle")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("Learn about Edge-Aware Directional Matching & Citations")
                                .popover(isPresented: $viewModel.showingEdgeMatchingInfo, arrowEdge: .trailing) {
                                    EdgeMatchingInfoView {
                                        viewModel.showingEdgeMatchingInfo = false
                                    }
                                }
                                
                                Spacer()
                                Text("\(Int(viewModel.edgeWeight * 100))%")
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                            }
                            .font(.caption)
                            Slider(value: $viewModel.edgeWeight, in: 0.0...1.0)
                                .disabled(viewModel.isRunning)
                                .help("Edge-Aware Directional Matching: aligns constituent photos' internal structural lines and contours with the target image")
                        }
                    }
                    .padding(.top, 4)
                }
                
                // Section 5: Memory Safety Badge
                HStack {
                    Image(systemName: viewModel.isMemorySafe ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(viewModel.isMemorySafe ? .green : .orange)
                    Text("RAM Footprint: ~\(viewModel.estimatedRAMText)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(viewModel.isMemorySafe ? "Safe" : "Caution")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(viewModel.isMemorySafe ? .green : .orange)
                }
                .padding(.horizontal, 4)
            }
            .padding()
        }
    }
    
    private func chooseSourceFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Add Photos"
        
        if panel.runModal() == .OK {
            for url in panel.urls {
                viewModel.addSourceFolder(url)
            }
        }
    }
    
    private func handleDroppedSources(_ providers: [NSItemProvider]) {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let fileURL = url else { return }
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir) {
                    DispatchQueue.main.async {
                        if isDir.boolValue {
                            viewModel.addSourceFolder(fileURL)
                        } else {
                            // If an image file was dropped, add its containing folder
                            let folder = fileURL.deletingLastPathComponent()
                            viewModel.addSourceFolder(folder)
                        }
                    }
                }
            }
        }
    }
}
