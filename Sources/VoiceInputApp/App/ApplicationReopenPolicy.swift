enum ApplicationWindowVisibility: Equatable {
    case notVisible
    case visible
    case miniaturized

    init(isVisible: Bool, isMiniaturized: Bool) {
        if isMiniaturized {
            self = .miniaturized
        } else if isVisible {
            self = .visible
        } else {
            self = .notVisible
        }
    }
}

enum ApplicationReopenAction: Equatable {
    case preserveVisibleWindowOrder
    case showMainWindow
}

enum ApplicationReopenPolicy {
    static func action(
        mainWindow: ApplicationWindowVisibility,
        settingsWindow: ApplicationWindowVisibility
    ) -> ApplicationReopenAction {
        if mainWindow == .visible || settingsWindow == .visible {
            return .preserveVisibleWindowOrder
        }
        return .showMainWindow
    }
}
