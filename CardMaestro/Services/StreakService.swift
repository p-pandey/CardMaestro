import Foundation
import CoreData

class StreakService: ObservableObject {
    private let viewContext: NSManagedObjectContext
    private let userDefaults = UserDefaults.standard
    
    @Published var currentStreak: Int = 0
    @Published var longestStreak: Int = 0
    @Published var lastStudyDate: Date?
    
    private let currentStreakKey = "currentStreak"
    private let longestStreakKey = "longestStreak"
    private let lastStudyDateKey = "lastStudyDate"
    
    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
        loadStreakData()
    }
    
    func recordStudySession() {
        let today = Calendar.current.startOfDay(for: Date())
        
        guard let lastDate = lastStudyDate else {
            startNewStreak(from: today)
            return
        }
        
        let lastStudyDay = Calendar.current.startOfDay(for: lastDate)
        let daysDifference = Calendar.current.dateComponents([.day], from: lastStudyDay, to: today).day ?? 0
        
        switch daysDifference {
        case 0:
            break
        case 1:
            currentStreak += 1
            if currentStreak > longestStreak {
                longestStreak = currentStreak
            }
            lastStudyDate = Date()
            saveStreakData()
        default:
            startNewStreak(from: today)
        }
    }
    
    func getStreakStatus() -> StreakStatus {
        guard let lastDate = lastStudyDate else {
            return .noStreak
        }
        
        let today = Calendar.current.startOfDay(for: Date())
        let lastStudyDay = Calendar.current.startOfDay(for: lastDate)
        let daysDifference = Calendar.current.dateComponents([.day], from: lastStudyDay, to: today).day ?? 0
        
        switch daysDifference {
        case 0:
            return .activeToday
        case 1:
            return .canContinue
        default:
            return .broken
        }
    }
    
    func getStudyStats() -> StudyStats {
        let sessions = fetchStudySessions()
        let totalSessions = sessions.count
        
        let totalCards = sessions.reduce(0) { $0 + Int($1.cardsReviewed) }
        
        let totalTime = sessions.compactMap { session -> TimeInterval? in
            guard let endTime = session.endTime else { return nil }
            return endTime.timeIntervalSince(session.startTime)
        }.reduce(0, +)
        
        let averageSessionTime = totalSessions > 0 ? totalTime / Double(totalSessions) : 0
        
        let daysStudied = Set(sessions.map { Calendar.current.startOfDay(for: $0.startTime) }).count
        
        return StudyStats(
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            totalSessions: totalSessions,
            totalCardsReviewed: totalCards,
            totalStudyTime: totalTime,
            averageSessionTime: averageSessionTime,
            daysStudied: daysStudied
        )
    }
    
    private func startNewStreak(from date: Date) {
        currentStreak = 1
        lastStudyDate = Date()
        if longestStreak == 0 {
            longestStreak = 1
        }
        saveStreakData()
    }
    
    private func loadStreakData() {
        currentStreak = userDefaults.integer(forKey: currentStreakKey)
        longestStreak = userDefaults.integer(forKey: longestStreakKey)
        lastStudyDate = userDefaults.object(forKey: lastStudyDateKey) as? Date
    }
    
    private func saveStreakData() {
        userDefaults.set(currentStreak, forKey: currentStreakKey)
        userDefaults.set(longestStreak, forKey: longestStreakKey)
        userDefaults.set(lastStudyDate, forKey: lastStudyDateKey)
    }
    
    private func fetchStudySessions() -> [StudySession] {
        let request: NSFetchRequest<StudySession> = StudySession.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \StudySession.startTime, ascending: false)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Error fetching study sessions: \(error)")
            return []
        }
    }
}

enum StreakStatus {
    case noStreak
    case activeToday
    case canContinue
    case broken
    
    var title: String {
        switch self {
        case .noStreak:
            return "Start your streak!"
        case .activeToday:
            return "Streak active"
        case .canContinue:
            return "Continue your streak"
        case .broken:
            return "Streak broken"
        }
    }
    
    var color: String {
        switch self {
        case .noStreak, .broken:
            return "gray"
        case .activeToday:
            return "green"
        case .canContinue:
            return "orange"
        }
    }
}

struct StudyStats {
    let currentStreak: Int
    let longestStreak: Int
    let totalSessions: Int
    let totalCardsReviewed: Int
    let totalStudyTime: TimeInterval
    let averageSessionTime: TimeInterval
    let daysStudied: Int
}