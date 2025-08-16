import SwiftUI
import UIKit

/// Texture system for cards that can use either programmatic textures or image assets
struct CardTextureSystem {
    
    /// Creates texture images or loads them from assets
    static func getTexture(for colorScheme: ColorScheme) -> UIImage {
        // Try to load from assets first, fallback to programmatic generation
        let imageName = colorScheme == .dark ? "card-texture-dark" : "card-texture-light"
        
        if let image = UIImage(named: imageName) {
            return image
        } else {
            // Fallback to programmatic generation
            return colorScheme == .dark 
                ? CardTextureBackgrounds.createDarkModeTexture()
                : CardTextureBackgrounds.createLightModeTexture()
        }
    }
}

/// Optimized card background with texture overlay
struct OptimizedTexturedCardBackground: View {
    let cardType: CardType
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Base color background
            RoundedRectangle(cornerRadius: 16)
                .fill(baseColor)
            
            // Texture overlay using ImagePaint
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    ImagePaint(
                        image: Image(uiImage: CardTextureSystem.getTexture(for: colorScheme)),
                        scale: textureScale
                    )
                )
                .opacity(textureOpacity)
                .blendMode(.multiply)
                .overlay(
                    // Card type accent border
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    cardType.color.opacity(borderOpacity),
                                    cardType.color.opacity(borderOpacity * 0.3),
                                    cardType.color.opacity(borderOpacity * 0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                )
                .overlay(
                    // Inner highlight for depth
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(innerHighlightOpacity),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                        .padding(0.5)
                )
        }
    }
    
    private var baseColor: Color {
        switch colorScheme {
        case .dark:
            return Color(red: 0.15, green: 0.25, blue: 0.45) // Dark blue to complement paperboard texture
        case .light:
            return Color(red: 0.94, green: 0.94, blue: 0.92) // Light linen
        @unknown default:
            return Color(red: 0.94, green: 0.94, blue: 0.92)
        }
    }
    
    private var textureScale: CGFloat {
        // Use 1x scale to show texture at original resolution
        1.0
    }
    
    private var textureOpacity: Double {
        colorScheme == .dark ? 0.75 : 0.65
    }
    
    private var borderOpacity: Double {
        colorScheme == .dark ? 0.35 : 0.25
    }
    
    private var innerHighlightOpacity: Double {
        colorScheme == .dark ? 0.08 : 0.15
    }
}

/// Instructions for texture images in Assets.xcassets:
/// 
/// Current texture configuration:
/// 1. Dark mode: Uses "card-texture-dark" - blue paperboard texture (JPG asset)
/// 2. Light mode: Uses programmatic light linen texture generation
/// 
/// The system prioritizes asset-based textures over programmatic generation:
/// - If "card-texture-dark" asset exists → uses the blue paperboard texture
/// - If "card-texture-light" asset exists → uses that instead of programmatic generation
/// - Otherwise falls back to programmatic texture generation
/// 
/// Image requirements:
/// - Format: JPG or PNG for best quality
/// - Size: Any size (ImagePaint handles scaling automatically)
/// - Dark texture: Currently uses blue paperboard texture for premium feel
/// - Light texture: Currently uses programmatic light linen/canvas weave

extension View {
    /// Applies optimized textured background to cards
    func optimizedTexturedBackground(cardType: CardType) -> some View {
        background(
            OptimizedTexturedCardBackground(cardType: cardType)
        )
    }
}