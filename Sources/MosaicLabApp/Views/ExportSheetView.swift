import SwiftUI
import AppKit

public struct ExportSheetView: View {
    @EnvironmentObject private var viewModel: MosaicViewModel
    @Environment(\.dismiss) private var dismiss
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Export Photomosaic")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Resolution Preset")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Picker("Resolution", selection: $viewModel.exportPreset) {
                    Text("Standard HD (2400 px)").tag(2400)
                    Text("High Resolution (3000 px)").tag(3000)
                    Text("4K UHD (3840 px)").tag(3840)
                    Text("Print Poster (6000 px)").tag(6000)
                    Text("Custom...").tag(-1)
                }
                .pickerStyle(.radioGroup)
                .onChange(of: viewModel.exportPreset) { val in
                    viewModel.exportIsCustom = (val == -1)
                }
                
                if viewModel.exportIsCustom {
                    HStack {
                        Text("Custom Width:")
                            .font(.caption)
                        TextField("Pixels", value: $viewModel.exportCustomWidth, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 90)
                        Text("px")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("File Format")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Picker("Format", selection: $viewModel.exportFormat) {
                    Text("HEIC (Recommended)").tag("HEIC")
                    Text("AVIF (Modern AV1)").tag("AVIF")
                    Text("PNG (Lossless)").tag("PNG")
                    Text("JPEG (Universal)").tag("JPG")
                }
                .pickerStyle(.radioGroup)
            }
            
            if let error = viewModel.exportErrorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                
                Spacer()
                
                Button(action: startExport) {
                    Text("Choose Destination & Export...")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 380)
    }
    
    private func startExport() {
        let width = viewModel.exportIsCustom ? viewModel.exportCustomWidth : viewModel.exportPreset
        let format = viewModel.exportFormat
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            viewModel.presentSavePanelAndExport(outputWidth: width, format: format)
        }
    }
}
