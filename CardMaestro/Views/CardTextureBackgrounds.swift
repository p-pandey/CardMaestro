import SwiftUI
import UIKit

/// Custom texture backgrounds for cards with realistic paper textures
struct CardTextureBackgrounds {
    
    /// Creates a programmatic texture that mimics the brown paper texture for dark mode
    static func createDarkModeTexture(size: CGSize = CGSize(width: 200, height: 200)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // Base brown color
            let baseColor = UIColor(red: 0.64, green: 0.49, blue: 0.35, alpha: 1.0) // Warm brown
            baseColor.setFill()
            cgContext.fill(CGRect(origin: .zero, size: size))
            
            // Add texture noise
            let noiseColor1 = UIColor(red: 0.58, green: 0.43, blue: 0.29, alpha: 0.3)
            let noiseColor2 = UIColor(red: 0.70, green: 0.55, blue: 0.41, alpha: 0.2)
            let noiseColor3 = UIColor(red: 0.52, green: 0.37, blue: 0.23, alpha: 0.4)
            
            // Create random noise pattern
            for _ in 0..<Int(size.width * size.height * 0.1) {
                let x = CGFloat.random(in: 0...size.width)
                let y = CGFloat.random(in: 0...size.height)
                let radius = CGFloat.random(in: 0.5...2.0)
                
                let color = [noiseColor1, noiseColor2, noiseColor3].randomElement()!
                color.setFill()
                
                cgContext.fillEllipse(in: CGRect(x: x, y: y, width: radius, height: radius))
            }
            
            // Add subtle gradient overlay
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                    colors: [
                                        UIColor(red: 0.68, green: 0.53, blue: 0.39, alpha: 0.1).cgColor,
                                        UIColor(red: 0.60, green: 0.45, blue: 0.31, alpha: 0.1).cgColor
                                    ] as CFArray,
                                    locations: [0.0, 1.0])!
            
            cgContext.drawLinearGradient(gradient,
                                       start: CGPoint(x: 0, y: 0),
                                       end: CGPoint(x: size.width, y: size.height),
                                       options: [])
            
            // Add subtle vertical lines for paper grain
            let lineColor = UIColor(red: 0.56, green: 0.41, blue: 0.27, alpha: 0.15)
            lineColor.setStroke()
            cgContext.setLineWidth(0.5)
            
            for i in stride(from: 0, to: Int(size.width), by: 3) {
                let x = CGFloat(i) + CGFloat.random(in: -0.5...0.5)
                cgContext.move(to: CGPoint(x: x, y: 0))
                cgContext.addLine(to: CGPoint(x: x, y: size.height))
                cgContext.strokePath()
            }
        }
    }
    
    /// Creates a programmatic texture that mimics the light linen texture for light mode
    static func createLightModeTexture(size: CGSize = CGSize(width: 200, height: 200)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // Base light linen color
            let baseColor = UIColor(red: 0.94, green: 0.94, blue: 0.92, alpha: 1.0) // Light linen
            baseColor.setFill()
            cgContext.fill(CGRect(origin: .zero, size: size))
            
            // Add linen texture with horizontal and vertical threads
            let threadColor1 = UIColor(red: 0.90, green: 0.90, blue: 0.88, alpha: 0.8)
            let threadColor2 = UIColor(red: 0.97, green: 0.97, blue: 0.95, alpha: 0.6)
            let threadColor3 = UIColor(red: 0.88, green: 0.88, blue: 0.86, alpha: 0.4)
            
            // Horizontal threads
            threadColor1.setStroke()
            cgContext.setLineWidth(1.0)
            
            for i in stride(from: 0, to: Int(size.height), by: 4) {
                let y = CGFloat(i) + CGFloat.random(in: -0.3...0.3)
                cgContext.move(to: CGPoint(x: 0, y: y))
                cgContext.addLine(to: CGPoint(x: size.width, y: y))
                cgContext.strokePath()
            }
            
            // Vertical threads
            threadColor2.setStroke()
            cgContext.setLineWidth(0.8)
            
            for i in stride(from: 0, to: Int(size.width), by: 3) {
                let x = CGFloat(i) + CGFloat.random(in: -0.2...0.2)
                cgContext.move(to: CGPoint(x: x, y: 0))
                cgContext.addLine(to: CGPoint(x: x, y: size.height))
                cgContext.strokePath()
            }
            
            // Add subtle random fiber texture
            for _ in 0..<Int(size.width * size.height * 0.08) {
                let x = CGFloat.random(in: 0...size.width)
                let y = CGFloat.random(in: 0...size.height)
                let width = CGFloat.random(in: 1.0...3.0)
                let height = CGFloat.random(in: 0.3...0.8)
                
                threadColor3.setFill()
                cgContext.fillEllipse(in: CGRect(x: x, y: y, width: width, height: height))
            }
            
            // Add very subtle gradient overlay
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                    colors: [
                                        UIColor(red: 0.96, green: 0.96, blue: 0.94, alpha: 0.05).cgColor,
                                        UIColor(red: 0.92, green: 0.92, blue: 0.90, alpha: 0.05).cgColor
                                    ] as CFArray,
                                    locations: [0.0, 1.0])!
            
            cgContext.drawLinearGradient(gradient,
                                       start: CGPoint(x: 0, y: 0),
                                       end: CGPoint(x: size.width, y: size.height),
                                       options: [])
        }
    }
}

/// Enhanced card background view with realistic texture overlays
struct TexturedCardBackgroundView: View {
    let cardType: CardType
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Base background with texture
            RoundedRectangle(cornerRadius: 16)
                .fill(baseColor)
                .overlay(
                    // Texture overlay
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            ImagePaint(
                                image: Image(uiImage: textureImage),
                                sourceRect: CGRect(x: 0, y: 0, width: 1, height: 1),
                                scale: 1.0
                            )
                        )
                        .opacity(textureOpacity)
                        .blendMode(.multiply)
                )
                .overlay(
                    // Subtle card type accent border
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    cardType.color.opacity(borderOpacity),
                                    cardType.color.opacity(borderOpacity * 0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        }
    }
    
    private var baseColor: Color {
        if colorScheme == .dark {
            return Color(red: 0.64, green: 0.49, blue: 0.35) // Warm brown base
        } else {
            return Color(red: 0.94, green: 0.94, blue: 0.92) // Light linen base
        }
    }
    
    private var textureImage: UIImage {
        if colorScheme == .dark {
            return CardTextureBackgrounds.createDarkModeTexture()
        } else {
            return CardTextureBackgrounds.createLightModeTexture()
        }
    }
    
    private var textureOpacity: Double {
        colorScheme == .dark ? 0.85 : 0.75
    }
    
    private var borderOpacity: Double {
        colorScheme == .dark ? 0.4 : 0.25
    }
}

/// View modifier to apply textured background to cards
struct TexturedCardBackground: ViewModifier {
    let cardType: CardType
    
    func body(content: Content) -> some View {
        content
            .background(
                TexturedCardBackgroundView(cardType: cardType)
            )
    }
}

extension View {
    /// Applies a textured background to cards
    func texturedCardBackground(cardType: CardType) -> some View {
        modifier(TexturedCardBackground(cardType: cardType))
    }
}