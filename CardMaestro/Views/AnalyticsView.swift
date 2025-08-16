import SwiftUI
import CoreData

struct AnalyticsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var streakService: StreakService
    @State private var stats: StudyStats?
    
    init(viewContext: NSManagedObjectContext) {
        self._streakService = StateObject(wrappedValue: StreakService(viewContext: viewContext))
    }
    
    var body: some View {
        NavigationView {
ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 20) {
                    streakSection
                    
                    if let stats = stats {
                        statsSection(stats)
                        timeSection(stats)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Progress")
            .onAppear {
                loadStats()
            }
        }
    }
    
    private var streakSection: some View {
        VStack(spacing: 16) {
            Text("Study Streak")
                .font(.title2)
                .fontWeight(.semibold)
            
            HStack(spacing: 40) {
                VStack(spacing: 8) {
                    Text("\(streakService.currentStreak)")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    
                    Text("Current")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 8) {
                    Text("\(streakService.longestStreak)")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    Text("Best")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            let status = streakService.getStreakStatus()
            Text(status.title)
                .font(.subheadline)
                .foregroundColor(colorFromString(status.color))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(colorFromString(status.color).opacity(0.1))
                .clipShape(Capsule())
        }
        .padding()
        .background(Color.gray.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func statsSection(_ stats: StudyStats) -> some View {
        VStack(spacing: 16) {
            Text("Study Statistics")
                .font(.title2)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                StatCard(
                    title: "Sessions",
                    value: "\(stats.totalSessions)",
                    icon: "play.circle.fill",
                    color: .green
                )
                
                StatCard(
                    title: "Cards Reviewed",
                    value: "\(stats.totalCardsReviewed)",
                    icon: "rectangle.stack.fill",
                    color: .blue
                )
                
                StatCard(
                    title: "Days Studied",
                    value: "\(stats.daysStudied)",
                    icon: "calendar.circle.fill",
                    color: .purple
                )
                
                StatCard(
                    title: "Total Time",
                    value: formatDuration(stats.totalStudyTime),
                    icon: "clock.fill",
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func timeSection(_ stats: StudyStats) -> some View {
        VStack(spacing: 16) {
            Text("Time Analysis")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                HStack {
                    Text("Average Session")
                        .font(.body)
                    
                    Spacer()
                    
                    Text(formatDuration(stats.averageSessionTime))
                        .font(.body)
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Text("Total Study Time")
                        .font(.body)
                    
                    Spacer()
                    
                    Text(formatDuration(stats.totalStudyTime))
                        .font(.body)
                        .fontWeight(.semibold)
                }
                
                if stats.daysStudied > 0 {
                    HStack {
                        Text("Average Per Day")
                            .font(.body)
                        
                        Spacer()
                        
                        let avgTime = stats.daysStudied > 0 ? stats.totalStudyTime / Double(stats.daysStudied) : 0
                        Text(formatDuration(avgTime))
                            .font(.body)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func loadStats() {
        stats = streakService.getStudyStats()
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func colorFromString(_ colorName: String) -> Color {
        switch colorName.lowercased() {
        case "red": return .red
        case "orange": return .orange
        case "green": return .green
        case "blue": return .blue
        case "gray": return .gray
        default: return .primary
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    AnalyticsView(viewContext: PersistenceController.preview.container.viewContext)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}