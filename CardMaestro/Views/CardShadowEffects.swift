import SwiftUI

/// Centralized shadow effects system for cards with adaptive dark/light mode support
struct CardShadowEffects {
    
    /// Primary shadow configuration for main card depth
    struct PrimaryShadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
        
        static func adaptive(colorScheme: ColorScheme) -> PrimaryShadow {
            if colorScheme == .dark {
                return PrimaryShadow(
                    color: .black.opacity(0.6),
                    radius: 12,
                    x: 0,
                    y: 6
                )
            } else {
                return PrimaryShadow(
                    color: .black.opacity(0.25),
                    radius: 16,
                    x: 0,
                    y: 8
                )
            }
        }
    }
    
    /// Secondary shadow for additional depth layering
    struct SecondaryShadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
        
        static func adaptive(colorScheme: ColorScheme) -> SecondaryShadow {
            if colorScheme == .dark {
                return SecondaryShadow(
                    color: .black.opacity(0.8),
                    radius: 4,
                    x: 0,
                    y: 2
                )
            } else {
                return SecondaryShadow(
                    color: .black.opacity(0.15),
                    radius: 6,
                    x: 0,
                    y: 3
                )
            }
        }
    }
    
    /// Colored accent shadow that matches card type
    struct AccentShadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
        
        static func adaptive(cardType: CardType, colorScheme: ColorScheme) -> AccentShadow {
            let baseOpacity: Double = colorScheme == .dark ? 0.4 : 0.2
            return AccentShadow(
                color: cardType.color.opacity(baseOpacity),
                radius: 8,
                x: 0,
                y: 4
            )
        }
    }
}

/// View modifier for applying layered card shadows
struct LayeredCardShadowModifier: ViewModifier {
    let cardType: CardType
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        let primary = CardShadowEffects.PrimaryShadow.adaptive(colorScheme: colorScheme)
        let secondary = CardShadowEffects.SecondaryShadow.adaptive(colorScheme: colorScheme)
        let accent = CardShadowEffects.AccentShadow.adaptive(cardType: cardType, colorScheme: colorScheme)
        
        content
            // Primary depth shadow
            .shadow(
                color: primary.color,
                radius: primary.radius,
                x: primary.x,
                y: primary.y
            )
            // Secondary close shadow for definition
            .shadow(
                color: secondary.color,
                radius: secondary.radius,
                x: secondary.x,
                y: secondary.y
            )
            // Subtle accent color shadow
            .shadow(
                color: accent.color,
                radius: accent.radius,
                x: accent.x,
                y: accent.y
            )
    }
}

/// View modifier for applying subtle element shadows (for text, icons, etc.)
struct ElementShadowModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .shadow(
                color: .black.opacity(colorScheme == .dark ? 0.7 : 0.3),
                radius: colorScheme == .dark ? 2 : 1,
                x: 0,
                y: colorScheme == .dark ? 1 : 0.5
            )
    }
}

/// View modifier for applying floating shadow effects to images
struct FloatingShadowModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .shadow(
                color: .black.opacity(colorScheme == .dark ? 0.6 : 0.4),
                radius: 8,
                x: 0,
                y: 4
            )
            .shadow(
                color: .black.opacity(colorScheme == .dark ? 0.3 : 0.1),
                radius: 2,
                x: 0,
                y: 1
            )
    }
}

// MARK: - View Extensions

extension View {
    /// Apply layered shadows optimized for card backgrounds
    func cardShadow(cardType: CardType) -> some View {
        modifier(LayeredCardShadowModifier(cardType: cardType))
    }
    
    /// Apply subtle shadows for text and UI elements
    func elementShadow() -> some View {
        modifier(ElementShadowModifier())
    }
    
    /// Apply floating shadows for images and media
    func floatingShadow() -> some View {
        modifier(FloatingShadowModifier())
    }
}