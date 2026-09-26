import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif
import CoreGraphics
import ImageIO
import MosaicLabKit

public struct MosaicCanvasView: View {
    @EnvironmentObject private var viewModel: MosaicViewModel
    
    public init() {}
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.platformCanvasBackground
                    .edgesIgnoringSafeArea(.all)
                
                if viewModel.targetCGImage != nil {
                    MosaicRepresentable(
                        canvasVersion: viewModel.canvasVersion,
                        engine: viewModel.engine,
                        targetImage: viewModel.targetCGImage,
                        blendOpacity: viewModel.blendOpacity,
                        strokeWidth: viewModel.strokeWidth,
                        strokeColor: viewModel.strokeColor,
                        colorTransferStrength: viewModel.colorTransferStrength,
                        isMonochrome: (viewModel.colorMetric == .monochrome),
                        onTileTapped: { tile in
                            viewModel.selectedTile = tile
                        },
                        onPan: { delta in
                            viewModel.panOffset = CGSize(
                                width: viewModel.panOffset.width + delta.width,
                                height: viewModel.panOffset.height + delta.height
                            )
                            viewModel.dragBaseOffset = viewModel.panOffset
                        },
                        onMagnify: { factor in
                            viewModel.zoomScale = max(0.25, min(4.0, viewModel.zoomScale * (1.0 + factor)))
                        }
                    )
                    .scaleEffect(viewModel.zoomScale)
                    .offset(viewModel.panOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { val in
                                viewModel.panOffset = CGSize(
                                    width: viewModel.dragBaseOffset.width + val.translation.width,
                                    height: viewModel.dragBaseOffset.height + val.translation.height
                                )
                            }
                            .onEnded { _ in
                                viewModel.dragBaseOffset = viewModel.panOffset
                            }
                    )
                    .padding(20)
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 3)
                    
                    // Floating Controls Bar (Zoom + Blend)
                    VStack {
                        Spacer()
                        HStack(spacing: 14) {
                            // Zoom Section
                            HStack(spacing: 6) {
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        viewModel.zoomScale = max(0.25, viewModel.zoomScale - 0.25)
                                    }
                                }) {
                                    Image(systemName: "minus.magnifyingglass")
                                        .font(.subheadline)
                                }
                                .buttonStyle(.plain)
                                .help("Zoom Out")
                                
                                Slider(value: $viewModel.zoomScale, in: 0.25...4.0)
                                    .frame(width: 90)
                                
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        viewModel.zoomScale = min(4.0, viewModel.zoomScale + 0.25)
                                    }
                                }) {
                                    Image(systemName: "plus.magnifyingglass")
                                        .font(.subheadline)
                                }
                                .buttonStyle(.plain)
                                .help("Zoom In")
                                
                                Text("\(Int(viewModel.zoomScale * 100))%")
                                    .font(.caption)
                                    .monospacedDigit()
                                    .foregroundColor(.secondary)
                                    .frame(width: 36, alignment: .trailing)
                                
                                Button("Fit") {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        viewModel.zoomScale = 1.0
                                        viewModel.panOffset = .zero
                                        viewModel.dragBaseOffset = .zero
                                    }
                                }
                                .controlSize(.small)
                                .buttonStyle(.bordered)
                                .help("Reset Zoom & Centering")
                            }
                            
                            Divider()
                                .frame(height: 16)
                            
                            // Blend Slider Section
                            HStack(spacing: 6) {
                                Image(systemName: "circle.lefthalf.filled")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("Blend:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Slider(value: $viewModel.blendOpacity, in: 0.0...1.0)
                                    .frame(width: 70)
                                Text("\(Int(viewModel.blendOpacity * 100))%")
                                    .font(.caption)
                                    .monospacedDigit()
                                    .foregroundColor(.secondary)
                                    .frame(width: 30, alignment: .trailing)
                            }
                            
                            Divider()
                                .frame(height: 16)
                            
                            // Color Transfer Slider Section
                            HStack(spacing: 6) {
                                Image(systemName: "paintpalette")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("Transfer:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Slider(value: $viewModel.colorTransferStrength, in: 0.0...1.0)
                                    .frame(width: 70)
                                Text("\(Int(viewModel.colorTransferStrength * 100))%")
                                    .font(.caption)
                                    .monospacedDigit()
                                    .foregroundColor(.secondary)
                                    .frame(width: 30, alignment: .trailing)
                                
                                if viewModel.colorTransferStrength > 0.0 {
                                    Button(action: {
                                        viewModel.colorTransferStrength = 0.0
                                    }) {
                                        Image(systemName: "arrow.counterclockwise")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Reset color transfer to 0%")
                                }
                                
                                Button(action: {
                                    viewModel.showingColorTransferInfo.toggle()
                                }) {
                                    Image(systemName: "info.circle")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("Learn about Reinhard Perceptual Color Transfer & Academic Citations")
                                .popover(isPresented: $viewModel.showingColorTransferInfo, arrowEdge: .top) {
                                    ColorTransferInfoView {
                                        viewModel.showingColorTransferInfo = false
                                    }
                                }
                            }
                            .help("Reinhard Perceptual Color Transfer: statistically harmonizes photo colors with the target image")
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 2)
                        .padding(.bottom, 16)
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("No Mosaic Loaded")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        Text("Drag a picture or a .macosaix project here to start.")
                            .font(.callout)
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                }
                
                if viewModel.isCanvasDropTargeted {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.accentColor, lineWidth: 3)
                        .background(Color.accentColor.opacity(0.08))
                        .padding(12)
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "arrow.down.doc.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.accentColor)
                                Text("Drop Project (.macosaix) or Target Image")
                                    .font(.headline)
                                    .foregroundColor(.accentColor)
                            }
                        )
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $viewModel.isCanvasDropTargeted) { providers in
                guard let provider = providers.first else { return false }
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let fileURL = url else { return }
                    DispatchQueue.main.async {
                        let ext = fileURL.pathExtension.lowercased()
                        if ext == "mosaiclab" || ext == "macosaix" {
                            viewModel.openProject(from: fileURL)
                        } else {
                            viewModel.proposeLayoutChange(description: "New Target Image (\(fileURL.lastPathComponent))") {
                                viewModel.setTargetImage(from: fileURL)
                            }
                        }
                    }
                }
                return true
            }
        }
    }
}

#if os(macOS)
private struct MosaicRepresentable: NSViewRepresentable {
    let canvasVersion: Int
    let engine: MosaicEngine?
    let targetImage: CGImage?
    let blendOpacity: Double
    let strokeWidth: Double
    let strokeColor: String
    let colorTransferStrength: Double
    let isMonochrome: Bool
    let onTileTapped: (MosaicTile) -> Void
    let onPan: (CGSize) -> Void
    let onMagnify: (CGFloat) -> Void
    
    func makeNSView(context: Context) -> NSMosaicView {
        let view = NSMosaicView()
        view.onTileTapped = onTileTapped
        view.onPan = onPan
        view.onMagnify = onMagnify
        return view
    }
    
    func updateNSView(_ nsView: NSMosaicView, context: Context) {
        nsView.canvasVersion = canvasVersion
        nsView.engine = engine
        nsView.targetImage = targetImage
        nsView.blendOpacity = blendOpacity
        nsView.strokeWidth = strokeWidth
        nsView.strokeColor = strokeColor
        nsView.colorTransferStrength = colorTransferStrength
        nsView.isMonochrome = isMonochrome
        nsView.onTileTapped = onTileTapped
        nsView.onPan = onPan
        nsView.onMagnify = onMagnify
        nsView.needsDisplay = true
    }
}

private final class NSMosaicView: NSView {
    var canvasVersion: Int = 0
    var engine: MosaicEngine?
    var targetImage: CGImage?
    var blendOpacity: Double = 0.0
    var strokeWidth: Double = 0.5
    var strokeColor: String = "black"
    var colorTransferStrength: Double = 0.0
    var isMonochrome: Bool = false
    var onTileTapped: ((MosaicTile) -> Void)?
    var onPan: ((CGSize) -> Void)?
    var onMagnify: ((CGFloat) -> Void)?
    
    // Cached offscreen mosaic backing image
    private var cachedMosaicImage: CGImage?
    private var cachedCanvasVersion: Int = -1
    private var cachedIsMonochrome: Bool = false
    private var cachedQuantizedTransfer: Int = -1
    private var cachedStrokeWidth: Double = -1.0
    private var cachedStrokeColor: String = ""
    private var cachedWidth: Int = -1
    private var cachedHeight: Int = -1
    private var cachedTilesCount: Int = -1
    
    override var isFlipped: Bool { true }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    override func scrollWheel(with event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            let factor = event.scrollingDeltaY * 0.005
            onMagnify?(factor)
        } else {
            let dx = event.scrollingDeltaX
            let dy = event.scrollingDeltaY
            onPan?(CGSize(width: dx, height: dy))
        }
    }
    
    override func magnify(with event: NSEvent) {
        onMagnify?(event.magnification)
    }
    
    override func mouseDown(with event: NSEvent) {
        guard let engine = self.engine else { return }
        let location = convert(event.locationInWindow, from: nil)
        
        let mSize = engine.mosaicSize
        guard mSize.width > 0, mSize.height > 0 else { return }
        let scale = min(bounds.width / mSize.width, bounds.height / mSize.height)
        let drawOriginX = (bounds.width - mSize.width * scale) / 2.0
        let drawOriginY = (bounds.height - mSize.height * scale) / 2.0
        
        // Convert to mosaic coordinates
        let mosaicPoint = CGPoint(
            x: (location.x - drawOriginX) / scale,
            y: (location.y - drawOriginY) / scale
        )
        
        // Find tapped tile
        for tile in engine.tiles {
            if tile.geometry.outline.contains(mosaicPoint) {
                onTileTapped?(tile)
                return
            }
        }
    }
    
    /// Draws an image right-side up inside a flipped NSView context
    private func drawUprightImage(_ image: CGImage, in rect: CGRect, in context: CGContext) {
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1.0, y: -1.0)
        context.draw(image, in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height))
        context.restoreGState()
    }
    
    /// Retrieves or rebuilds the offscreen mosaic image.
    /// When only blendOpacity changes, returns the cached image instantly (0% CPU, 120 FPS).
    private func getOrRebuildMosaicImage(engine: MosaicEngine, target: CGImage, displayScale: CGFloat) -> CGImage? {
        let mSize = engine.mosaicSize
        let width = Int(mSize.width)
        let height = Int(mSize.height)
        guard width > 0, height > 0 else { return nil }
        
        let quantizedTransfer = Int(round(colorTransferStrength * 20.0)) * 5
        let currentTilesCount = engine.tiles.count
        let isMono = self.isMonochrome || (engine.metric == .monochrome)
        
        // Fast path: if cache is valid, return immediately (zero tile loops!)
        if let cached = cachedMosaicImage,
           cachedCanvasVersion == self.canvasVersion,
           cachedIsMonochrome == isMono,
           cachedQuantizedTransfer == quantizedTransfer,
           abs(cachedStrokeWidth - self.strokeWidth) < 0.001,
           cachedStrokeColor == self.strokeColor,
           cachedWidth == width,
           cachedHeight == height,
           cachedTilesCount == currentTilesCount {
            return cached
        }
        
        // Rebuild offscreen mosaic image
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }
        
        ctx.interpolationQuality = .high
        
        // Transform context so (0,0) is top-left, matching tile geometry and NSView isFlipped
        ctx.translateBy(x: 0, y: CGFloat(height))
        ctx.scaleBy(x: 1.0, y: -1.0)
        
        let transferStrength = Float(colorTransferStrength)
        let strokeW = CGFloat(strokeWidth)
        let strokeLineWidth = (displayScale > 0.0) ? strokeW / displayScale : strokeW
        let displayTarget = isMono ? ColorTransfer.convertToMonochrome(target) : target
        
        let hasUnmatchedTiles = engine.tiles.contains { $0.bestImageURL == nil }
        if hasUnmatchedTiles {
            drawUprightImage(displayTarget, in: CGRect(origin: .zero, size: mSize), in: ctx)
            ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.35))
            ctx.fill(CGRect(origin: .zero, size: mSize))
        }
        
        for tile in engine.tiles {
            if let imageURL = tile.bestImageURL {
                ctx.saveGState()
                ctx.addPath(tile.geometry.outline)
                ctx.clip()
                
                let targetStats = (transferStrength > 0.001) ? tile.targetColorStatistics : nil
                if let cgImg = MosaicThumbnailCache.shared.thumbnail(
                    for: imageURL,
                    targetStats: targetStats,
                    colorTransferStrength: transferStrength,
                    isMonochrome: isMono
                ) {
                    let b = tile.geometry.bounds
                    let imgW = CGFloat(cgImg.width)
                    let imgH = CGFloat(cgImg.height)
                    let fillScale = max(b.width / imgW, b.height / imgH)
                    let drawW = imgW * fillScale
                    let drawH = imgH * fillScale
                    let drawX = b.midX - drawW / 2.0
                    let drawY = b.midY - drawH / 2.0
                    
                    drawUprightImage(cgImg, in: CGRect(x: drawX, y: drawY, width: drawW, height: drawH), in: ctx)
                }
                ctx.restoreGState()
            }
            
            if strokeW > 0.01 {
                ctx.saveGState()
                let strokeCol = (self.strokeColor == "white") ?
                    CGColor(red: 1, green: 1, blue: 1, alpha: 0.6) :
                    CGColor(red: 0, green: 0, blue: 0, alpha: 0.35)
                ctx.setStrokeColor(strokeCol)
                ctx.setLineWidth(strokeLineWidth)
                ctx.addPath(tile.geometry.outline)
                ctx.strokePath()
                ctx.restoreGState()
            }
        }
        
        guard let newImage = ctx.makeImage() else { return nil }
        self.cachedMosaicImage = newImage
        self.cachedCanvasVersion = self.canvasVersion
        self.cachedIsMonochrome = isMono
        self.cachedQuantizedTransfer = quantizedTransfer
        self.cachedStrokeWidth = self.strokeWidth
        self.cachedStrokeColor = self.strokeColor
        self.cachedWidth = width
        self.cachedHeight = height
        self.cachedTilesCount = currentTilesCount
        return newImage
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext,
              let engine = self.engine,
              let target = self.targetImage else {
            return
        }
        
        let mSize = engine.mosaicSize
        guard mSize.width > 0, mSize.height > 0 else { return }
        
        let scale = min(bounds.width / mSize.width, bounds.height / mSize.height)
        let drawOriginX = (bounds.width - mSize.width * scale) / 2.0
        let drawOriginY = (bounds.height - mSize.height * scale) / 2.0
        
        guard let mosaicImage = getOrRebuildMosaicImage(engine: engine, target: target, displayScale: scale) else {
            return
        }
        
        context.saveGState()
        context.translateBy(x: drawOriginX, y: drawOriginY)
        context.scaleBy(x: scale, y: scale)
        
        // 1. Draw cached mosaic image upright (instant 1-blit GPU draw!)
        drawUprightImage(mosaicImage, in: CGRect(origin: .zero, size: mSize), in: context)
        
        // 2. Draw "Blend with Original" overlay upright if blendOpacity > 0.01
        if blendOpacity > 0.01 {
            context.saveGState()
            context.setAlpha(CGFloat(blendOpacity))
            let isMono = self.isMonochrome || (engine.metric == .monochrome)
            let blendTarget = isMono ? ColorTransfer.convertToMonochrome(target) : target
            drawUprightImage(blendTarget, in: CGRect(origin: .zero, size: mSize), in: context)
            context.restoreGState()
        }
        
        context.restoreGState()
    }
}
#else
private struct MosaicRepresentable: UIViewRepresentable {
    let canvasVersion: Int
    let engine: MosaicEngine?
    let targetImage: CGImage?
    let blendOpacity: Double
    let strokeWidth: Double
    let strokeColor: String
    let colorTransferStrength: Double
    let isMonochrome: Bool
    let onTileTapped: (MosaicTile) -> Void
    let onPan: (CGSize) -> Void
    let onMagnify: (CGFloat) -> Void
    
    func makeUIView(context: Context) -> UIMosaicView {
        let view = UIMosaicView()
        view.onTileTapped = onTileTapped
        view.onPan = onPan
        view.onMagnify = onMagnify
        return view
    }
    
    func updateUIView(_ uiView: UIMosaicView, context: Context) {
        uiView.canvasVersion = canvasVersion
        uiView.engine = engine
        uiView.targetImage = targetImage
        uiView.blendOpacity = blendOpacity
        uiView.strokeWidth = strokeWidth
        uiView.strokeColor = strokeColor
        uiView.colorTransferStrength = colorTransferStrength
        uiView.isMonochrome = isMonochrome
        uiView.onTileTapped = onTileTapped
        uiView.onPan = onPan
        uiView.onMagnify = onMagnify
        uiView.setNeedsDisplay()
    }
}

private final class UIMosaicView: UIView {
    var canvasVersion: Int = 0
    var engine: MosaicEngine?
    var targetImage: CGImage?
    var blendOpacity: Double = 0.0
    var strokeWidth: Double = 0.5
    var strokeColor: String = "black"
    var colorTransferStrength: Double = 0.0
    var isMonochrome: Bool = false
    var onTileTapped: ((MosaicTile) -> Void)?
    var onPan: ((CGSize) -> Void)?
    var onMagnify: ((CGFloat) -> Void)?
    
    private var cachedMosaicImage: CGImage?
    private var cachedCanvasVersion: Int = -1
    private var cachedIsMonochrome: Bool = false
    private var cachedQuantizedTransfer: Int = -1
    private var cachedStrokeWidth: Double = -1.0
    private var cachedStrokeColor: String = ""
    private var cachedWidth: Int = -1
    private var cachedHeight: Int = -1
    private var cachedTilesCount: Int = -1
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tapGesture)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let engine = self.engine else { return }
        let location = gesture.location(in: self)
        let mSize = engine.mosaicSize
        guard mSize.width > 0, mSize.height > 0 else { return }
        let scale = min(bounds.width / mSize.width, bounds.height / mSize.height)
        let drawOriginX = (bounds.width - mSize.width * scale) / 2.0
        let drawOriginY = (bounds.height - mSize.height * scale) / 2.0
        
        let mosaicPoint = CGPoint(
            x: (location.x - drawOriginX) / scale,
            y: (location.y - drawOriginY) / scale
        )
        for tile in engine.tiles {
            if tile.geometry.outline.contains(mosaicPoint) {
                onTileTapped?(tile)
                return
            }
        }
    }
    
    private func drawUprightImage(_ image: CGImage, in rect: CGRect, in context: CGContext) {
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1.0, y: -1.0)
        context.draw(image, in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height))
        context.restoreGState()
    }
    
    private func getOrRebuildMosaicImage(engine: MosaicEngine, target: CGImage, displayScale: CGFloat) -> CGImage? {
        let mSize = engine.mosaicSize
        let width = Int(mSize.width)
        let height = Int(mSize.height)
        guard width > 0, height > 0 else { return nil }
        
        let quantizedTransfer = Int(round(colorTransferStrength * 20.0)) * 5
        let currentTilesCount = engine.tiles.count
        let isMono = self.isMonochrome || (engine.metric == .monochrome)
        
        if let cached = cachedMosaicImage,
           cachedCanvasVersion == self.canvasVersion,
           cachedIsMonochrome == isMono,
           cachedQuantizedTransfer == quantizedTransfer,
           abs(cachedStrokeWidth - self.strokeWidth) < 0.001,
           cachedStrokeColor == self.strokeColor,
           cachedWidth == width,
           cachedHeight == height,
           cachedTilesCount == currentTilesCount {
            return cached
        }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }
        
        ctx.interpolationQuality = .high
        ctx.translateBy(x: 0, y: CGFloat(height))
        ctx.scaleBy(x: 1.0, y: -1.0)
        
        let transferStrength = Float(colorTransferStrength)
        let strokeW = CGFloat(strokeWidth)
        let strokeLineWidth = (displayScale > 0.0) ? strokeW / displayScale : strokeW
        let displayTarget = isMono ? ColorTransfer.convertToMonochrome(target) : target
        
        let hasUnmatchedTiles = engine.tiles.contains { $0.bestImageURL == nil }
        if hasUnmatchedTiles {
            drawUprightImage(displayTarget, in: CGRect(origin: .zero, size: mSize), in: ctx)
            ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.35))
            ctx.fill(CGRect(origin: .zero, size: mSize))
        }
        
        for tile in engine.tiles {
            if let imageURL = tile.bestImageURL {
                ctx.saveGState()
                ctx.addPath(tile.geometry.outline)
                ctx.clip()
                
                let targetStats = (transferStrength > 0.001) ? tile.targetColorStatistics : nil
                if let cgImg = MosaicThumbnailCache.shared.thumbnail(
                    for: imageURL,
                    targetStats: targetStats,
                    colorTransferStrength: transferStrength,
                    isMonochrome: isMono
                ) {
                    let b = tile.geometry.bounds
                    let imgW = CGFloat(cgImg.width)
                    let imgH = CGFloat(cgImg.height)
                    let fillScale = max(b.width / imgW, b.height / imgH)
                    let drawW = imgW * fillScale
                    let drawH = imgH * fillScale
                    let drawX = b.midX - drawW / 2.0
                    let drawY = b.midY - drawH / 2.0
                    drawUprightImage(cgImg, in: CGRect(x: drawX, y: drawY, width: drawW, height: drawH), in: ctx)
                }
                ctx.restoreGState()
            }
            
            if strokeW > 0.01 {
                ctx.saveGState()
                let strokeCol = (self.strokeColor == "white") ?
                    CGColor(red: 1, green: 1, blue: 1, alpha: 0.6) :
                    CGColor(red: 0, green: 0, blue: 0, alpha: 0.35)
                ctx.setStrokeColor(strokeCol)
                ctx.setLineWidth(strokeLineWidth)
                ctx.addPath(tile.geometry.outline)
                ctx.strokePath()
                ctx.restoreGState()
            }
        }
        
        guard let newImage = ctx.makeImage() else { return nil }
        self.cachedMosaicImage = newImage
        self.cachedCanvasVersion = self.canvasVersion
        self.cachedIsMonochrome = isMono
        self.cachedQuantizedTransfer = quantizedTransfer
        self.cachedStrokeWidth = self.strokeWidth
        self.cachedStrokeColor = self.strokeColor
        self.cachedWidth = width
        self.cachedHeight = height
        self.cachedTilesCount = currentTilesCount
        return newImage
    }
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(),
              let engine = self.engine,
              let target = self.targetImage else { return }
        
        let mSize = engine.mosaicSize
        guard mSize.width > 0, mSize.height > 0 else { return }
        
        let scale = min(bounds.width / mSize.width, bounds.height / mSize.height)
        let drawOriginX = (bounds.width - mSize.width * scale) / 2.0
        let drawOriginY = (bounds.height - mSize.height * scale) / 2.0
        
        guard let mosaicImage = getOrRebuildMosaicImage(engine: engine, target: target, displayScale: scale) else { return }
        
        context.saveGState()
        context.translateBy(x: drawOriginX, y: drawOriginY)
        context.scaleBy(x: scale, y: scale)
        
        drawUprightImage(mosaicImage, in: CGRect(origin: .zero, size: mSize), in: context)
        
        if blendOpacity > 0.01 {
            context.saveGState()
            context.setAlpha(CGFloat(blendOpacity))
            let isMono = self.isMonochrome || (engine.metric == .monochrome)
            let blendTarget = isMono ? ColorTransfer.convertToMonochrome(target) : target
            drawUprightImage(blendTarget, in: CGRect(origin: .zero, size: mSize), in: context)
            context.restoreGState()
        }
        
        context.restoreGState()
    }
}
#endif
