import Foundation
import CoreGraphics

#if os(macOS)
import AppKit
public typealias PlatformImage = NSImage
public typealias PlatformColor = NSColor
#elseif os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
import UIKit
public typealias PlatformImage = UIImage
public typealias PlatformColor = UIColor
#endif
