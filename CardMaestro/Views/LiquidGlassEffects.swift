import SwiftUI

/// Apple's Liquid Glass effect system for icons and images on cards
/// This translucent material reflects and refracts its surroundings while dynamically transforming
struct LiquidGlassEffects {
    
    /// Creates a dynamic glass reflection gradient that simulates light refraction
    static func glassReflectionGradient(for colorScheme: ColorScheme) -> LinearGradient {
        let reflectionColors: [Color] = {
            if colorScheme == .dark {
                return [
                    Color.white.opacity(0.15),
                    Color.white.opacity(0.08),
                    Color.clear,
                    Color.white.opacity(0.05),
                    Color.white.opacity(0.12)
                ]
            } else {
                return [
                    Color.white.opacity(0.25),
                    Color.white.opacity(0.15),
                    Color.clear,
                    Color.white.opacity(0.08),
                    Color.white.opacity(0.18)
                ]
            }
        }()
        
        return LinearGradient(
            colors: reflectionColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Creates a refractive surface that bends light around the edges
    static func refractiveEdgeGradient(for colorScheme: ColorScheme) -> RadialGradient {
        let edgeColors: [Color] = {
            if colorScheme == .dark {
                return [
                    Color.clear,
                    Color.white.opacity(0.06),
                    Color.white.opacity(0.12),
                    Color.white.opacity(0.08)
                ]
            } else {
                return [
                    Color.clear,
                    Color.white.opacity(0.08),
                    Color.white.opacity(0.18),
                    Color.white.opacity(0.12)
                ]
            }
        }()
        
        return RadialGradient(
            colors: edgeColors,
            center: .topLeading,
            startRadius: 0,
            endRadius: 100
        )
    }
    
    /// Creates a subtle prismatic color separation effect
    static func prismaticGradient(baseColor: Color, colorScheme: ColorScheme) -> LinearGradient {
        let intensity: Double = colorScheme == .dark ? 0.08 : 0.06
        
        return LinearGradient(
            colors: [
                baseColor.opacity(intensity),
                Color.blue.opacity(intensity * 0.3),
                Color.clear,
                Color.red.opacity(intensity * 0.2),
                baseColor.opacity(intensity * 0.5)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// Liquid Glass effect modifier for small icons (type icons, flip icons)
struct LiquidGlassIcon: ViewModifier {
    let baseColor: Color
    @Environment(\.colorScheme) var colorScheme
    @State private var animationPhase: Double = 0
    
    func body(content: Content) -> some View {
        content
            .background(
                // Base translucent layer
                RoundedRectangle(cornerRadius: 8)
                    .fill(.ultraThinMaterial)
                    .opacity(materialOpacity)
            )
            .overlay(
                // Primary glass reflection
                RoundedRectangle(cornerRadius: 8)
                    .fill(LiquidGlassEffects.glassReflectionGradient(for: colorScheme))
                    .scaleEffect(1.0 + sin(animationPhase) * 0.02)
                    .animation(
                        .easeInOut(duration: 3.0).repeatForever(autoreverses: true),
                        value: animationPhase
                    )
            )
            .overlay(
                // Refractive edge highlights
                RoundedRectangle(cornerRadius: 8)
                    .fill(LiquidGlassEffects.refractiveEdgeGradient(for: colorScheme))
                    .rotationEffect(.degrees(animationPhase * 2))
                    .animation(
                        .linear(duration: 8.0).repeatForever(autoreverses: false),
                        value: animationPhase
                    )
            )
            .overlay(
                // Prismatic color separation
                RoundedRectangle(cornerRadius: 8)
                    .fill(LiquidGlassEffects.prismaticGradient(baseColor: baseColor, colorScheme: colorScheme))
                    .offset(x: sin(animationPhase * 0.5) * 0.5, y: cos(animationPhase * 0.3) * 0.5)
                    .animation(
                        .easeInOut(duration: 4.0).repeatForever(autoreverses: true),
                        value: animationPhase
                    )
            )
            .overlay(
                // Subtle inner glow
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        LinearGradient(
                            colors: [
                                baseColor.opacity(glowIntensity),
                                Color.clear,
                                baseColor.opacity(glowIntensity * 0.5)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .onAppear {
                animationPhase = Double.random(in: 0...2 * .pi)
            }
    }
    
    private var materialOpacity: Double {
        colorScheme == .dark ? 0.4 : 0.3
    }
    
    private var glowIntensity: Double {
        colorScheme == .dark ? 0.15 : 0.12
    }
}

/// Liquid Glass effect modifier for large images (vocabulary/fact cards)
struct LiquidGlassLargeImage: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) var colorScheme
    @State private var animationPhase: Double = 0
    @State private var reflectionOffset: CGSize = .zero
    
    func body(content: Content) -> some View {
        content
            .overlay(
                // Primary glass surface reflection
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(glassOpacity),
                                Color.clear,
                                Color.white.opacity(glassOpacity * 0.3),
                                Color.clear,
                                Color.white.opacity(glassOpacity * 0.6)
                            ],
                            startPoint: UnitPoint(x: 0.2 + reflectionOffset.width * 0.001, 
                                                y: 0.1 + reflectionOffset.height * 0.001),
                            endPoint: UnitPoint(x: 0.8 + reflectionOffset.width * 0.001, 
                                              y: 0.9 + reflectionOffset.height * 0.001)
                        )
                    )
                    .animation(
                        .easeInOut(duration: 5.0).repeatForever(autoreverses: true),
                        value: reflectionOffset
                    )
            )
            .overlay(
                // Dynamic light caustics
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(causticIntensity),
                                Color.clear,
                                Color.white.opacity(causticIntensity * 0.5),
                                Color.clear
                            ],
                            center: UnitPoint(x: 0.5 + sin(animationPhase) * 0.2, 
                                            y: 0.5 + cos(animationPhase * 0.7) * 0.2),
                            startRadius: 10,
                            endRadius: 80
                        )
                    )
                    .scaleEffect(1.0 + sin(animationPhase * 1.3) * 0.05)
                    .animation(
                        .easeInOut(duration: 6.0).repeatForever(autoreverses: true),
                        value: animationPhase
                    )
            )
            .overlay(
                // Edge refraction highlights
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(edgeHighlightOpacity),
                                Color.clear,
                                Color.white.opacity(edgeHighlightOpacity * 0.7),
                                Color.clear,
                                Color.white.opacity(edgeHighlightOpacity * 0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.0
                    )
                    .rotationEffect(.degrees(sin(animationPhase * 0.2) * 2))
                    .animation(
                        .linear(duration: 12.0).repeatForever(autoreverses: false),
                        value: animationPhase
                    )
            )
            .onAppear {
                animationPhase = Double.random(in: 0...2 * .pi)
                
                // Start reflection animation
                withAnimation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true)) {
                    reflectionOffset = CGSize(width: 20, height: 30)
                }
            }
    }
    
    private var glassOpacity: Double {
        colorScheme == .dark ? 0.12 : 0.08
    }
    
    private var causticIntensity: Double {
        colorScheme == .dark ? 0.08 : 0.06
    }
    
    private var edgeHighlightOpacity: Double {
        colorScheme == .dark ? 0.15 : 0.12
    }
}

/// Liquid Glass effect modifier for small images (conjugation cards)
struct LiquidGlassSmallImage: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) var colorScheme
    @State private var animationPhase: Double = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                // Compact glass reflection
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(reflectionOpacity),
                                Color.clear,
                                Color.white.opacity(reflectionOpacity * 0.5)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(1.0 + sin(animationPhase) * 0.03)
                    .animation(
                        .easeInOut(duration: 4.0).repeatForever(autoreverses: true),
                        value: animationPhase
                    )
            )
            .overlay(
                // Subtle edge glow
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        Color.white.opacity(edgeGlowOpacity),
                        lineWidth: 0.5
                    )
                    .opacity(0.5 + sin(animationPhase * 1.5) * 0.3)
                    .animation(
                        .easeInOut(duration: 3.0).repeatForever(autoreverses: true),
                        value: animationPhase
                    )
            )
            .onAppear {
                animationPhase = Double.random(in: 0...2 * .pi)
            }
    }
    
    private var reflectionOpacity: Double {
        colorScheme == .dark ? 0.1 : 0.08
    }
    
    private var edgeGlowOpacity: Double {
        colorScheme == .dark ? 0.12 : 0.1
    }
}

// MARK: - View Extensions

extension View {
    /// Applies Liquid Glass effect to small icons
    func liquidGlassIcon(baseColor: Color) -> some View {
        modifier(LiquidGlassIcon(baseColor: baseColor))
    }
    
    /// Applies Liquid Glass effect to large images
    func liquidGlassLargeImage(cornerRadius: CGFloat = 12) -> some View {
        modifier(LiquidGlassLargeImage(cornerRadius: cornerRadius))
    }
    
    /// Applies Liquid Glass effect to small images
    func liquidGlassSmallImage(cornerRadius: CGFloat = 8) -> some View {
        modifier(LiquidGlassSmallImage(cornerRadius: cornerRadius))
    }
}