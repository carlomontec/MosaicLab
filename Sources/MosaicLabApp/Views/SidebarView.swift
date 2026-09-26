import SwiftUI
#if os(macOS)
import AppKit
#endif
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
                        if viewModel.hasCompletedTiles {
                            HStack(spacing: 6) {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.secondary)
                                Text("Grid locked (\(viewModel.matchedTilesCount) matches)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.vertical, 2)
                        }
                        
                        Picker("Shape", selection: Binding(
                            get: { viewModel.shapeType },
                            set: { newShape in
                                if newShape != viewModel.shapeType {
                                    let name = (newShape == .quadtree) ? "Adaptive Quadtree" : "Uniform Grid"
                                    viewModel.proposeLayoutChange(description: "Tile Shape to \(name)") {
                                        viewModel.shapeType = newShape
                                    }
                                }
                            }
                        )) {
                            Text("Uniform Grid").tag(MosaicShapeType.rectangular)
                            Text("Adaptive Quadtree").tag(MosaicShapeType.quadtree)
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
                                set: { newVal in
                                    let val = Int(newVal)
                                    if val != viewModel.tilesAcross {
                                        let label = viewModel.shapeType == .quadtree ? "Base Grid Across" : "Tiles Across"
                                        viewModel.proposeLayoutChange(description: "\(label) to \(val)") {
                                            viewModel.tilesAcross = val
                                        }
                                    }
                                }
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
                                set: { newVal in
                                    let val = Int(newVal)
                                    if val != viewModel.tilesDown {
                                        let label = viewModel.shapeType == .quadtree ? "Base Grid Down" : "Tiles Down"
                                        viewModel.proposeLayoutChange(description: "\(label) to \(val)") {
                                            viewModel.tilesDown = val
                                        }
                                    }
                                }
                            ), in: (viewModel.shapeType == .quadtree ? 4...24 : 10...60), step: 2)
                            .disabled(viewModel.isRunning)
                        }
                        
                        if viewModel.shapeType == .quadtree {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Segmentation Algorithm:")
                                    .font(.caption)
                                Picker("", selection: Binding(
                                    get: { viewModel.quadtreeAlgorithm },
                                    set: { newAlgo in
                                        if newAlgo != viewModel.quadtreeAlgorithm {
                                            viewModel.proposeLayoutChange(description: "Segmentation Algorithm") {
                                                viewModel.quadtreeAlgorithm = newAlgo
                                            }
                                        }
                                    }
                                )) {
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
                                Picker("", selection: Binding(
                                    get: { viewModel.quadtreeMinTileDim },
                                    set: { newDim in
                                        if newDim != viewModel.quadtreeMinTileDim {
                                            viewModel.proposeLayoutChange(description: "Min Tile Size to \(Int(newDim)) px") {
                                                viewModel.quadtreeMinTileDim = newDim
                                            }
                                        }
                                    }
                                )) {
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
                                    set: { newVal in
                                        let val = Int(newVal)
                                        if val != viewModel.quadtreeMaxDepth {
                                            viewModel.proposeLayoutChange(description: "Max Subdivision to Level \(val)") {
                                                viewModel.quadtreeMaxDepth = val
                                            }
                                        }
                                    }
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
                                        let thresh = round((0.85 - (newSens * 0.80)) * 1000.0) / 1000.0
                                        if thresh != viewModel.quadtreeThreshold {
                                            let sensPct = Int(round(newSens * 100))
                                            viewModel.proposeLayoutChange(description: "Detail Sensitivity to \(sensPct)%") {
                                                viewModel.quadtreeThreshold = thresh
                                            }
                                        }
                                    }
                                ), in: 0.0...1.0, step: 0.01)
                                .disabled(viewModel.isRunning)
                            }
                            
                            Toggle("2:1 Balanced Transitions", isOn: Binding(
                                get: { viewModel.quadtreeBalanced },
                                set: { newBal in
                                    if newBal != viewModel.quadtreeBalanced {
                                        viewModel.proposeLayoutChange(description: "2:1 Balanced Transitions") {
                                            viewModel.quadtreeBalanced = newBal
                                        }
                                    }
                                }
                            ))
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
                                            let newAlpha: Double
                                            switch mode {
                                            case "edge": newAlpha = 0.2
                                            case "texture": newAlpha = 0.8
                                            default: newAlpha = 0.5
                                            }
                                            if newAlpha != viewModel.quadtreeDetailAlpha {
                                                viewModel.proposeLayoutChange(description: "Detail Mode") {
                                                    viewModel.quadtreeDetailAlpha = newAlpha
                                                }
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
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Tile Outlines:")
                                Spacer()
                                Text(viewModel.strokeWidth > 0 ? String(format: "%.1f px", viewModel.strokeWidth) : "Off")
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                            }
                            .font(.caption)
                            Slider(value: $viewModel.strokeWidth, in: 0.0...2.0, step: 0.25)
                            
                            if viewModel.strokeWidth > 0 {
                                HStack {
                                    Text("Outline Color:")
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
                                Toggle(isOn: Binding(
                                    get: { viewModel.useApplePhotos },
                                    set: { newVal in
                                        if newVal != viewModel.useApplePhotos {
                                            viewModel.proposeLayoutChange(description: "Apple Photos Source") {
                                                viewModel.useApplePhotos = newVal
                                            }
                                        }
                                    }
                                )) {
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
                                        Picker("", selection: Binding(
                                            get: { viewModel.selectedAlbumID },
                                            set: { newAlbum in
                                                if newAlbum != viewModel.selectedAlbumID {
                                                    viewModel.proposeLayoutChange(description: "Photos Album Selection") {
                                                        viewModel.selectedAlbumID = newAlbum
                                                    }
                                                }
                                            }
                                        )) {
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
                            Toggle(isOn: Binding(
                                get: { viewModel.useLocalFolders },
                                set: { newVal in
                                    if newVal != viewModel.useLocalFolders {
                                        viewModel.proposeLayoutChange(description: "Local Folders Source") {
                                            viewModel.useLocalFolders = newVal
                                        }
                                    }
                                }
                            )) {
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
                                            viewModel.proposeLayoutChange(description: "Remove Folder (\(folder.lastPathComponent))") {
                                                viewModel.removeSourceFolder(folder)
                                            }
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
                                set: { newVal in
                                    let val = Int(newVal)
                                    if val != viewModel.maxReuse {
                                        let label = val == 0 ? "Unlimited" : "\(val)×"
                                        viewModel.proposeLayoutChange(description: "Max Reuse to \(label)") {
                                            viewModel.maxReuse = val
                                        }
                                    }
                                }
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
                                set: { newVal in
                                    let val = Int(newVal)
                                    if val != viewModel.minDistance {
                                        viewModel.proposeLayoutChange(description: "Min Distance to \(val) tiles") {
                                            viewModel.minDistance = val
                                        }
                                    }
                                }
                            ), in: 0...6, step: 1)
                            .disabled(viewModel.isRunning)
                        }
                        
                        Picker("Metric", selection: Binding(
                            get: { viewModel.colorMetric },
                            set: { newMetric in
                                if newMetric != viewModel.colorMetric {
                                    let label = (newMetric == .riemersma) ? "Riemersma (Eye)" : (newMetric == .RGB ? "RGB Distance" : "Monochrome (B&W)")
                                    viewModel.proposeLayoutChange(description: "Color Metric to \(label)") {
                                        viewModel.colorMetric = newMetric
                                    }
                                }
                            }
                        )) {
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
                            Slider(value: Binding(
                                get: { viewModel.edgeWeight },
                                set: { newVal in
                                    let rounded = round(newVal * 100.0) / 100.0
                                    if abs(rounded - viewModel.edgeWeight) > 0.02 {
                                        let pct = Int(round(rounded * 100))
                                        viewModel.proposeLayoutChange(description: "Edge Alignment to \(pct)%") {
                                            viewModel.edgeWeight = rounded
                                        }
                                    }
                                }
                            ), in: 0.0...1.0)
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
        .disabled(viewModel.isExporting || viewModel.isLoadingProject)
    }
    
    private func chooseSourceFolder() {
        guard !viewModel.isExporting, !viewModel.isLoadingProject else { return }
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Add Photos"
        
        if panel.runModal() == .OK {
            let selectedURLs = panel.urls
            viewModel.proposeLayoutChange(description: "Add Photo Folders") {
                viewModel.useLocalFolders = true
                for url in selectedURLs {
                    viewModel.addSourceFolder(url)
                }
            }
        }
        #else
        viewModel.isFolderPickerPresented = true
        #endif
    }
    
    private func handleDroppedSources(_ providers: [NSItemProvider]) {
        guard !viewModel.isExporting, !viewModel.isLoadingProject else { return }
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let fileURL = url else { return }
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir) {
                    DispatchQueue.main.async {
                        let folderToAdd = isDir.boolValue ? fileURL : fileURL.deletingLastPathComponent()
                        viewModel.proposeLayoutChange(description: "Add Photo Folder (\(folderToAdd.lastPathComponent))") {
                            viewModel.useLocalFolders = true
                            viewModel.addSourceFolder(folderToAdd)
                        }
                    }
                }
            }
        }
    }
}
