//
//  PNGRenderer.swift
//  VoxelSprite
//
//  Pixel-Canvas zu CGImage/PNG Rendering.
//  Plattformübergreifend (macOS + iOS).
//

import SwiftUI
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

struct PNGRenderer {

    var transparentBackground: Bool = true

    // MARK: - Canvas → CGImage (quadratisch)

    func renderCanvasToCGImage(_ canvas: PixelCanvas, gridSize: Int) -> CGImage? {
        guard let context = CGContext(
            data: nil,
            width: gridSize,
            height: gridSize,
            bitsPerComponent: 8,
            bytesPerRow: gridSize * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        if !transparentBackground {
            context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: gridSize, height: gridSize))
        }

        for y in 0..<gridSize {
            for x in 0..<gridSize {
                if let color = canvas.pixel(at: x, y: y),
                   let c = color.cgColorComponents {
                    context.setFillColor(red: c.r, green: c.g, blue: c.b, alpha: c.a)
                    context.fill(CGRect(x: x, y: gridSize - 1 - y, width: 1, height: 1))
                }
            }
        }
        return context.makeImage()
    }

    // MARK: - Canvas → CGImage (beliebige Größe)

    func renderCanvasToFullCGImage(_ canvas: PixelCanvas) -> CGImage? {
        let w = canvas.width
        let h = canvas.height

        guard let context = CGContext(
            data: nil,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        if !transparentBackground {
            context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: w, height: h))
        }

        for y in 0..<h {
            for x in 0..<w {
                if let color = canvas.pixel(at: x, y: y),
                   let components = color.cgColorComponents {
                    context.setFillColor(red: components.r,
                                         green: components.g,
                                         blue: components.b,
                                         alpha: components.a)
                    context.fill(CGRect(x: x, y: h - 1 - y, width: 1, height: 1))
                }
            }
        }

        return context.makeImage()
    }

    // MARK: - Animierter Strip (Minecraft-Format)

    func renderAnimatedStrip(face: BlockFace, gridSize: Int) -> CGImage? {
        let frameCount = face.frames.count
        guard frameCount > 0 else { return nil }

        let width = gridSize
        let totalHeight = gridSize * frameCount

        guard let context = CGContext(
            data: nil,
            width: width,
            height: totalHeight,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        if !transparentBackground {
            context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: width, height: totalHeight))
        }

        for (frameIndex, canvas) in face.frames.enumerated() {
            let yOffset = (frameCount - 1 - frameIndex) * gridSize

            for y in 0..<gridSize {
                for x in 0..<gridSize {
                    if let color = canvas.pixel(at: x, y: y),
                       let c = color.cgColorComponents {
                        context.setFillColor(red: c.r, green: c.g, blue: c.b, alpha: c.a)
                        context.fill(CGRect(
                            x: x,
                            y: yOffset + (gridSize - 1 - y),
                            width: 1,
                            height: 1
                        ))
                    }
                }
            }
        }

        return context.makeImage()
    }

    // MARK: - CGImage → PNG Data

    func cgImageToPNGData(_ image: CGImage) -> Data? {
        #if canImport(UIKit)
        return UIImage(cgImage: image).pngData()
        #elseif canImport(AppKit)
        let rep = NSBitmapImageRep(cgImage: image)
        return rep.representation(using: .png, properties: [:])
        #else
        return nil
        #endif
    }
}
