import Foundation
import AVFoundation
import UIKit

class SoundService: ObservableObject {
    static let shared = SoundService()
    
    // MARK: - Properties
    @Published var soundsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(soundsEnabled, forKey: "soundsEnabled")
        }
    }
    
    @Published var hapticsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(hapticsEnabled, forKey: "hapticsEnabled")
        }
    }
    
    private func setupAudioSession() {
        do {
            // Use .playback category to respect system volume controls
            // This ensures sounds are muted when system volume is 0
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    // MARK: - System Sound Effects
    
    /// Plays when the app starts up
    func playAppStartup() {
        playSound(1000) // New mail sound - welcoming tone
        playHaptic { lightHaptic() }
    }
    
    /// Plays when user starts a study session
    func playStudyStart() {
        playSound(1003) // Text tone - focused, ready sound
        playHaptic { mediumHaptic() }
    }
    
    /// Plays when flipping a card
    func playCardFlip() {
        playSound(1104) // Camera shutter - satisfying flip sound
        playHaptic { lightHaptic() }
    }
    
    /// Plays for correct/good answer
    func playCorrectAnswer() {
        playSound(1054) // Swoosh - positive feedback
        playHaptic { successHaptic() }
    }
    
    /// Plays for easy answer (mastered)
    func playEasyAnswer() {
        playSound(1013) // Tweet - cheerful success
        playHaptic { successHaptic() }
    }
    
    /// Plays for hard/difficult answer
    func playHardAnswer() {
        playSound(1006) // Tock - neutral but noticeable
        playHaptic { warningHaptic() }
    }
    
    /// Plays for wrong/again answer
    func playWrongAnswer() {
        playSound(1053) // Pop - gentle negative feedback
        playHaptic { errorHaptic() }
    }
    
    /// Plays when adding a new card
    func playCardAdded() {
        playSound(1001) // Mail sent - accomplishment sound
        playHaptic { lightHaptic() }
    }
    
    /// Plays when a new deck is created
    func playDeckCreated() {
        playSound(1012) // Task completed - significant accomplishment sound
        playHaptic { successHaptic() }
    }
    
    /// Plays when session completes successfully
    func playSessionComplete() {
        playSound(1025) // Anticipate - celebration tone
        playHaptic { heavyHaptic() }
    }
    
    /// Plays for general button taps
    func playButtonTap() {
        playSound(1110) // Keyboard click - subtle interaction feedback
        playHaptic { lightHaptic() }
    }
    
    /// Plays when generating suggestions
    func playSuggestionGenerated() {
        playSound(1016) // Alert - notification of new content
        playHaptic { mediumHaptic() }
    }
    
    /// Plays when deleting/archiving cards
    func playCardDeleted() {
        playSound(1020) // Pop - confirmation of action
        playHaptic { warningHaptic() }
    }
    
    /// Plays for each stat tick during count-up
    func playStatTick() {
        playSound(1103) // SMS received - quick, subtle tick
    }
    
    /// Plays when a stat category completes counting
    func playStatComplete() {
        playSound(1005) // Swoosh - satisfying completion sound
        playHaptic { lightHaptic() }
    }
    
    // MARK: - Haptic Feedback
    
    private func lightHaptic() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func mediumHaptic() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    private func heavyHaptic() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
    }
    
    private func successHaptic() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
    }
    
    private func warningHaptic() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.warning)
    }
    
    private func errorHaptic() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.error)
    }
    
    // MARK: - Initialization
    private init() {
        self.soundsEnabled = UserDefaults.standard.object(forKey: "soundsEnabled") as? Bool ?? true
        self.hapticsEnabled = UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool ?? true
        setupAudioSession()
    }
    
    // MARK: - Conditional Play Methods
    
    private func playSound(_ soundID: SystemSoundID) {
        guard soundsEnabled else { return }
        AudioServicesPlaySystemSound(soundID)
    }
    
    private func playHaptic(_ hapticClosure: () -> Void) {
        guard hapticsEnabled else { return }
        hapticClosure()
    }
}

// MARK: - System Sound ID Reference
/*
Common iOS System Sound IDs:
1000 - New Mail
1001 - Mail Sent
1003 - Text Tone
1004 - Voicemail
1005 - Tweet Sent
1006 - Tock
1013 - Tweet
1016 - Alert
1020 - Pop
1025 - Anticipate
1053 - Pop
1054 - Swoosh
1104 - Camera Shutter/Peek
1105 - Begin Video Recording
1106 - End Video Recording
1107 - Begin Video Recording Tock
1108 - End Video Recording Tock
1109 - Screenshot
1110 - Keyboard Press Click
1111 - Keyboard Delete
1112 - Keyboard Modifier
*/