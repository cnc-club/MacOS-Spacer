import Foundation

enum Localization {
    static var language: String {
        let value = UserDefaults.standard.string(forKey: "appLanguage") ?? "en"
        return ["en", "ru"].contains(value) ? value : "en"
    }
    static var resourceBundle: Bundle {
        if let resources = Bundle.main.resourceURL,
           let packaged = Bundle(path: resources.appendingPathComponent("Spacer_Spacer.bundle").path) { return packaged }
        #if SWIFT_PACKAGE
        return .module
        #else
        return .main
        #endif
    }
    static func text(_ key: String, arguments: [String] = []) -> String {
        let path = resourceBundle.path(forResource: language, ofType: "lproj")
        let bundle = path.flatMap(Bundle.init(path:)) ?? resourceBundle
        let format = bundle.localizedString(forKey: key, value: key, table: nil)
        return String(format: format, locale: Locale(identifier: language), arguments: arguments)
    }
}
func T(_ key: String, _ arguments: String...) -> String { Localization.text(key, arguments: arguments) }

indirect enum LocalizedMessage {
    case phrase(String, [String])
    case joined([LocalizedMessage])
    init(_ key: String, _ arguments: String...) { self = .phrase(key, arguments) }
    var text: String {
        switch self {
        case .phrase(let key, let arguments): return Localization.text(key, arguments: arguments)
        case .joined(let messages): return messages.map(\.text).joined(separator: " · ")
        }
    }
}
