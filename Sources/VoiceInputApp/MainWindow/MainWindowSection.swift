import Foundation

enum MainWindowSection: String, CaseIterable, Identifiable {
    case home
    case dictionary
    case models
    case readiness
    case preferences

    var id: String { rawValue }

    func title(for language: UILanguage) -> String {
        let copy = AppCopy.texts(for: language)
        switch self {
        case .home: return copy.homeTitle
        case .dictionary: return copy.dictionaryTitle
        case .models: return copy.modelsTitle
        case .readiness: return copy.readinessTitle
        case .preferences: return copy.preferencesTitle
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "square.grid.2x2"
        case .dictionary: return "doc.text"
        case .models: return "shippingbox"
        case .readiness: return "checklist.checked"
        case .preferences: return "slider.horizontal.3"
        }
    }
}
