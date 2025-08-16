import SwiftUI
import UIKit

/// Custom texture backgrounds for cards with realistic paper textures
struct CardTextureBackgrounds {
    
    /// Creates a programmatic texture that mimics a dark concrete/asphalt texture for dark mode
    static func createDarkModeTexture(size: CGSize = CGSize(width: 200, height: 200)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // Base very dark color - like dark concrete/asphalt
            let baseColor = UIColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0) // Very dark gray
            baseColor.setFill()
            cgContext.fill(CGRect(origin: .zero, size: size))
            
            // Add fine granular noise texture for concrete/asphalt look
            let lightSpeckles = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 0.8)
            let mediumSpeckles = UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 0.6)
            let darkSpeckles = UIColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 0.5)
            
            // Create fine granular texture
            for _ in 0..<Int(size.width * size.height * 0.3) {
                let x = CGFloat.random(in: 0...size.width)
                let y = CGFloat.random(in: 0...size.height)
                let radius = CGFloat.random(in: 0.3...0.8)
                
                let color = [lightSpeckles, mediumSpeckles, darkSpeckles].randomElement()!
                color.setFill()
                
                cgContext.fillEllipse(in: CGRect(x: x, y: y, width: radius, height: radius))
            }
            
            // Add slightly larger speckles for varied texture
            for _ in 0..<Int(size.width * size.height * 0.1) {
                let x = CGFloat.random(in: 0...size.width)
                let y = CGFloat.random(in: 0...size.height)
                let radius = CGFloat.random(in: 1.0...2.5)
                
                let brightness = CGFloat.random(in: 0.1...0.25)
                let color = UIColor(red: brightness, green: brightness, blue: brightness, alpha: 0.4)
                color.setFill()
                
                cgContext.fillEllipse(in: CGRect(x: x, y: y, width: radius, height: radius))
            }
            
            // Add subtle variation with noise
            for _ in 0..<Int(size.width * size.height * 0.05) {
                let x = CGFloat.random(in: 0...size.width)
                let y = CGFloat.random(in: 0...size.height)
                let width = CGFloat.random(in: 1.5...4.0)
                let height = CGFloat.random(in: 0.5...1.5)
                
                let brightness = CGFloat.random(in: 0.05...0.18)
                let color = UIColor(red: brightness, green: brightness, blue: brightness, alpha: 0.3)
                color.setFill()
                
                cgContext.fillEllipse(in: CGRect(x: x, y: y, width: width, height: height))
            }
            
            // Add very subtle gradient for depth
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                    colors: [
                                        UIColor(red: 0.14, green: 0.14, blue: 0.14, alpha: 0.1).cgColor,
                                        UIColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 0.1).cgColor
                                    ] as CFArray,
                                    locations: [0.0, 1.0])!
            
            cgContext.drawLinearGradient(gradient,
                                       start: CGPoint(x: 0, y: 0),
                                       end: CGPoint(x: size.width, y: size.height),
                                       options: [])
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
            return Color(red: 0.15, green: 0.25, blue: 0.45) // Dark blue to complement paperboard texture
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