import SwiftUI

struct SplashView: View {
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0.0
    @State private var rotationAngle: Double = 0
    @State private var showText = false
    
    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    Color.white,
                    Color.purple.opacity(0.1),
                    Color.blue.opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // App icon with animations
                ZStack {
                    // Background circle with subtle animation
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.2), Color.blue.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 200, height: 200)
                        .scaleEffect(scale * 0.8)
                        .opacity(opacity * 0.6)
                    
                    // Main app icon
                    if let appIcon = UIImage(named: "CardMaestro_AppIcon_1024") {
                        Image(uiImage: appIcon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .scaleEffect(scale)
                            .opacity(opacity)
                            .rotationEffect(.degrees(rotationAngle))
                            .shadow(color: .purple.opacity(0.3), radius: 8, x: 0, y: 4)
                    } else {
                        // Fallback to the beautiful CM icon design
                        ZStack {
                            // Recreate the stacked cards design from your app icon
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.yellow.opacity(0.9))
                                .frame(width: 120, height: 120)
                                .offset(x: 8, y: 8)
                                .rotationEffect(.degrees(5))
                            
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.teal)
                                .frame(width: 120, height: 120)
                                .offset(x: 4, y: 4)
                                .rotationEffect(.degrees(2))
                            
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.red)
                                .frame(width: 120, height: 120)
                            
                            // CM letters
                            Text("CM")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .scaleEffect(scale)
                        .opacity(opacity)
                        .rotationEffect(.degrees(rotationAngle))
                        .shadow(color: .purple.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                }
                
                // App name with staggered animation
                if showText {
                    VStack(spacing: 8) {
                        Text("CardMaestro")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        
                        Text("Master Your Memory")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .transition(.move(edge: .bottom).combined(with: .opacity).animation(.easeOut.delay(0.2)))
                    }
                }
            }
        }
        .onAppear {
            // Play startup sound
            SoundService.shared.playAppStartup()
            
            // Staggered entrance animations
            withAnimation(.spring(response: 1.2, dampingFraction: 0.8)) {
                scale = 1.2
                opacity = 1.0
            }
            
            // Subtle rotation animation
            withAnimation(.easeInOut(duration: 0.8).delay(0.3)) {
                rotationAngle = 5
            }
            
            // Scale back to normal
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    scale = 1.0
                    rotationAngle = 0
                }
            }
            
            // Show text with delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeOut(duration: 0.8)) {
                    showText = true
                }
            }
        }
    }
}

#Preview {
    SplashView()
}