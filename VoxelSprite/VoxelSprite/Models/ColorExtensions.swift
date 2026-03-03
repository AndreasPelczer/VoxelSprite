//
//  ColorExtensions.swift
//  VoxelSprite
//
//  Zentrale Color-Extensions für Hex-Konvertierung und
//  RGBA-Komponentenzugriff (plattformübergreifend).
//

import SwiftUI

// MARK: - RGBA Component Extraction

extension Color {

    /// Extrahiert die RGBA-Komponenten als CGFloat-Tupel.
    /// Funktioniert plattformübergreifend (macOS via NSColor, iOS via UIColor).
    var cgColorComponents: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)? {
        #if canImport(AppKit)
        guard let nsColor = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        nsColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
        #elseif canImport(UIKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return (r, g, b, a)
        #else
        return nil
        #endif
    }
}

// MARK: - Hex String Initializer

extension Color {

    /// Erzeugt eine Color aus einem Hex-String.
    /// Unterstützt: #RGB, #RRGGBB, #RRGGBBAA (mit oder ohne #)
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b, a: Double

        switch hex.count {
        case 3: // RGB (4-bit)
            r = Double((int >> 8) & 0xF) / 15.0
            g = Double((int >> 4) & 0xF) / 15.0
            b = Double(int & 0xF) / 15.0
            a = 1.0
        case 6: // RRGGBB
            r = Double((int >> 16) & 0xFF) / 255.0
            g = Double((int >> 8) & 0xFF) / 255.0
            b = Double(int & 0xFF) / 255.0
            a = 1.0
        case 8: // RRGGBBAA
            r = Double((int >> 24) & 0xFF) / 255.0
            g = Double((int >> 16) & 0xFF) / 255.0
            b = Double((int >> 8) & 0xFF) / 255.0
            a = Double(int & 0xFF) / 255.0
        default:
            r = 0; g = 0; b = 0; a = 1
        }

        self.init(red: r, green: g, blue: b, opacity: a)
    }
}
