import Foundation
import Combine

/// 用户设置存储层：@Published + didSet 持久化到 UserDefaults
final class SettingsStore: ObservableObject {
    @Published var soundEnabled: Bool { didSet { defaults.set(soundEnabled, forKey: Key.soundEnabled) } }
    @Published var soundForDone: String { didSet { defaults.set(soundForDone, forKey: Key.soundForDone) } }
    @Published var soundForConfirm: String { didSet { defaults.set(soundForConfirm, forKey: Key.soundForConfirm) } }
    @Published var soundForError: String { didSet { defaults.set(soundForError, forKey: Key.soundForError) } }
    @Published var port: UInt16 { didSet { defaults.set(Int(port), forKey: Key.port) } }
    @Published var token: String { didSet { defaults.set(token, forKey: Key.token) } }
    @Published var launchAtLogin: Bool { didSet { defaults.set(launchAtLogin, forKey: Key.launchAtLogin) } }
    @Published var traeCodeBundleID: String { didSet { defaults.set(traeCodeBundleID, forKey: Key.traeCodeBundleID) } }
    @Published var traeWorkBundleID: String { didSet { defaults.set(traeWorkBundleID, forKey: Key.traeWorkBundleID) } }

    private let defaults = UserDefaults.standard

    private enum Key {
        static let soundEnabled = "soundEnabled"
        static let soundForDone = "soundForDone"
        static let soundForConfirm = "soundForConfirm"
        static let soundForError = "soundForError"
        static let port = "port"
        static let token = "token"
        static let launchAtLogin = "launchAtLogin"
        static let traeCodeBundleID = "traeCodeBundleID"
        static let traeWorkBundleID = "traeWorkBundleID"
    }

    init() {
        soundEnabled = defaults.object(forKey: Key.soundEnabled) as? Bool ?? true
        soundForDone = defaults.string(forKey: Key.soundForDone) ?? "Glass"
        soundForConfirm = defaults.string(forKey: Key.soundForConfirm) ?? "Ping"
        soundForError = defaults.string(forKey: Key.soundForError) ?? "Basso"
        port = UInt16(defaults.object(forKey: Key.port) as? Int ?? 17387)
        token = defaults.string(forKey: Key.token) ?? ""
        launchAtLogin = defaults.bool(forKey: Key.launchAtLogin)
        traeCodeBundleID = defaults.string(forKey: Key.traeCodeBundleID) ?? ""
        traeWorkBundleID = defaults.string(forKey: Key.traeWorkBundleID) ?? ""
    }
}
