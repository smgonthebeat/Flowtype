import Combine
import Foundation

@MainActor
final class MainWindowState: ObservableObject {
    @Published var selectedSection: MainWindowSection = .home
    @Published private(set) var refreshID = UUID()

    func show(_ section: MainWindowSection) {
        selectedSection = section
        refresh()
    }

    func refresh() {
        refreshID = UUID()
    }
}
