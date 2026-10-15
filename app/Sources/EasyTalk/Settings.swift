import EasyTalkCore
import Foundation

/// Small UserDefaults-backed settings store.
enum Settings {
    private static let d = UserDefaults.standard

    static var speechEngine: SpeechEngineChoice {
        get { SpeechEngineChoice(rawValue: d.string(forKey: "speechEngine") ?? "") ?? .parakeet }
        set { d.set(newValue.rawValue, forKey: "speechEngine") }
    }

    static var setupComplete: Bool {
        get { d.bool(forKey: "setupComplete") }
        set { d.set(newValue, forKey: "setupComplete") }
    }

    /// Custom spellings (R19). Edited in Settings in M4; can be set now with
    /// `defaults write com.coreyashmeade.easytalk wordList -array GTM Acme`.
    static var wordList: [String] { d.stringArray(forKey: "wordList") ?? [] }

    static var soundsOn: Bool { d.object(forKey: "soundsOn") as? Bool ?? true }
}
