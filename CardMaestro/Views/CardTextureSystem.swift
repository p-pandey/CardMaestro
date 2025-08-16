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
                        image: Image(uiImage: CardTextureSystem.getTexture(for: colorScheme))
                            .resizable(resizingMode: .tile),
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
            return Color(red: 0.64, green: 0.49, blue: 0.35) // Warm brown
        case .light:
            return Color(red: 0.94, green: 0.94, blue: 0.92) // Light linen
        @unknown default:
            return Color(red: 0.94, green: 0.94, blue: 0.92)
        }
    }
    
    private var textureScale: CGFloat {
        // Adjust scale based on device size for consistent texture appearance
        UIScreen.main.bounds.width > 400 ? 0.8 : 1.0
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

/// Instructions for adding texture images to Assets.xcassets:
/// 
/// To use custom texture images instead of programmatic textures:
/// 1. Add your texture images to Assets.xcassets with these names:
///    - "card-texture-dark" (for the brown texture in dark mode)
///    - "card-texture-light" (for the light linen texture in light mode)
/// 2. The system will automatically use these images if available
/// 3. The textures should be seamlessly tileable for best results
/// 4. Recommended size: 200x200 pixels for optimal performance
/// 
/// Image requirements:
/// - Format: PNG for best quality
/// - Size: 200x200px to 400x400px 
/// - Should tile seamlessly (no visible edges when repeated)
/// - Dark texture: warm brown paper-like texture
/// - Light texture: light linen/canvas weave texture

extension View {
    /// Applies optimized textured background to cards
    func optimizedTexturedBackground(cardType: CardType) -> some View {
        background(
            OptimizedTexturedCardBackground(cardType: cardType)
        )
    }
}