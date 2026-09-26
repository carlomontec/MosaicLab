import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

extension Color {
    public static var platformCanvasBackground: Color {
        #if os(macOS)
        return Color(NSColor.underPageBackgroundColor)
        #else
        return Color(uiColor: .systemGroupedBackground)
        #endif
    }
    
    public static var platformControlBackground: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(uiColor: .secondarySystemBackground)
        #endif
    }
    
    public static var platformWindowBackground: Color {
        #if os(macOS)
        return Color(NSColor.windowBackgroundColor)
        #else
        return Color(uiColor: .systemBackground)
        #endif
    }
}
